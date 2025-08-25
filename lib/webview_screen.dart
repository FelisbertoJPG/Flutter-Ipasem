import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'services/ipasem_js.dart';
import 'services/session_manager.dart';
import 'widgets/ipasem_alert.dart';

import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'services/file_upload_manager.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
    show AndroidWebViewController, FileSelectorMode;

class WebViewScreen extends StatefulWidget {
  final String url;
  final String? title;
  final String? initialCpf;
  final WebViewController? prewarmed;

  const WebViewScreen({
    super.key,
    required this.url,
    this.title,
    this.initialCpf,
    this.prewarmed,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> with WidgetsBindingObserver {
  late final WebViewController _controller;

  int _progress = 0;
  bool _loading = false;
  Timer? _bgTimer;
  bool _openedExternal = false;
  bool _didWipe = false;

  static const String _logoutUrl = 'https://assistweb.ipasemnh.com.br/site/logout';
  static const List<String> _pdfEndpoints = [
    '/reimpressao/imprimir-segunda-via',
    '/reimpressao/imprimir-autorizacao',
    '/emitir-comprovante',
    '/ordem/historico-pdf',
    '/imprimir-ordem',
  ];
  bool _isPdfEndpoint(String url) => _pdfEndpoints.any((e) => url.contains(e));

  void _showLoading() => setState(() => _loading = true);
  void _hideLoading() => setState(() => _loading = false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // controller com suporte a file chooser no Android
    if (widget.prewarmed != null) {
      _controller = widget.prewarmed!;
    } else {
      const params = PlatformWebViewControllerCreationParams();
      _controller = WebViewController.fromPlatformCreationParams(params);
    }

    // Hook do seletor de arquivos (Android)
    if (_controller.platform is AndroidWebViewController) {
      final android = _controller.platform as AndroidWebViewController;
      android.setOnShowFileSelector((p) async {
        // p.acceptTypes (List<String>), p.mode (FileSelectorMode)
        final multiple = p.mode == FileSelectorMode.openMultiple;
        return await FileUploadManager.pick(
          acceptTypes: p.acceptTypes,
          allowMultiple: multiple,
        );
      });
    }

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('UI', onMessageReceived: (m) {
        final msg = m.message.trim().toLowerCase();
        if (msg == 'loading:on') _showLoading();
        if (msg == 'loading:off') _hideLoading();
      })
      ..addJavaScriptChannel('Token', onMessageReceived: (m) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token_login', m.message);
      })
      ..addJavaScriptChannel('Downloader', onMessageReceived: (msg) async {
        try {
          final map = jsonDecode(msg.message) as Map<String, dynamic>;
          final name = (map['name'] as String?)?.trim();
          final dataUrl = map['dataUrl'] as String;

          final i = dataUrl.indexOf('base64,');
          if (i < 0) throw Exception('DataURL inválido');
          final b64 = dataUrl.substring(i + 7);
          final bytes = base64Decode(b64);

          final dir = await getTemporaryDirectory();
          final safeName = (name?.isNotEmpty == true ? name! : 'documento.pdf')
              .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

          final file = File('${dir.path}/$safeName');
          await file.writeAsBytes(bytes);

          _openedExternal = true;
          await OpenFilex.open(file.path);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Falha ao abrir PDF: $e')),
            );
          }
        } finally {
          _hideLoading();
        }
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onPageFinished: (_) async {
            await IpasemJs.injectInto(_controller, cpf: widget.initialCpf);

            final token = await IpasemJs.readToken(_controller);
            if (token != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('token_login', token);
            }

            // Fallback: se o site não desligar pelo canal JS, desligamos aqui.
            _hideLoading();
          },
          onNavigationRequest: (req) async {
            final url = req.url;
            final lower = url.toLowerCase();

            // Só esses esquemas vão para fora do app
            if (lower.startsWith('tel:') ||
                lower.startsWith('mailto:') ||
                lower.startsWith('whatsapp:') ||
                lower.startsWith('intent:')) {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                _openedExternal = true;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              }
            }

            // Intercepta PDF/endpoints
            if (lower.endsWith('.pdf') || _isPdfEndpoint(url)) {
              _showLoading();
              await IpasemJs.downloadThroughWebView(_controller, url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (_) => _hideLoading(),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // limpar sessão ao sair da tela (hardware back / pop / fechar app)
  Future<void> _logoutAndWipe() async {
    if (_didWipe) return;
    _didWipe = true;
    try {
      await _controller.runJavaScript(r'''
        (async function(){
          try{ await fetch("''' + _logoutUrl + r'''", {method:'POST', credentials:'include'}); }
          catch(e){ try{ await fetch("''' + _logoutUrl + r'''", {credentials:'include'}); }catch(_){ } }
          try{ localStorage.clear(); }catch(_){}
          try{ sessionStorage.clear(); }catch(_){}
          try{
            if (window.caches){
              const ks = await caches.keys();
              for (const k of ks){ await caches.delete(k); }
            }
          }catch(_){}
        })();
      ''');
    } catch (_) {}
    await SessionManager.wipeAll(_controller);
  }

  // back físico respeita histórico da WebView
  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false; // fica na tela
    }
    await _logoutAndWipe(); // saindo da tela -> limpa sessão
    return true; // permite Navigator.pop()
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bgTimer?.cancel();
      _openedExternal = false;
    }
    if (state == AppLifecycleState.paused) {
      if (_openedExternal) return; // não desloga se abriu PDF/app externo
      _bgTimer?.cancel();
      _bgTimer = Timer(const Duration(minutes: 5), _logoutAndWipe);
    }
    if (state == AppLifecycleState.detached) {
      _logoutAndWipe();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgTimer?.cancel();
    // Garantia extra: se o usuário saiu da tela por qualquer motivo, limpa sessão.
    _logoutAndWipe(); // não dá pra await em dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
              if (_loading)
                const IpasemAlertOverlay(
                  message: 'PDF sendo gerado, aguarde...',
                  type: IpasemAlertType.loading,
                  showProgress: true,
                  badgeVariant: IpasemBadgeVariant.printLike,
                  badgeRadius: 22,
                  badgeIconSize: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
