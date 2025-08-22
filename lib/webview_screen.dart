// webview_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'services/session_manager.dart';
import 'widgets/ipasem_alert.dart';

/// Tela de WebView com:
/// • Interceptação/Download de PDFs (inclusive endpoints sem .pdf)
/// • Comunicação JS ↔ Flutter via JavaScriptChannels (UI/Downloader)
/// • Overlay de loading controlado pelo JS
/// • Autofill de CPF no formulário
/// • Botão “voltar” que respeita histórico da WebView
/// • Logout + limpeza de sessão quando fecha/manda app pro background
class WebViewScreen extends StatefulWidget {
  final String url;         // URL inicial da página
  final String? title;      // Título da AppBar
  final String? initialCpf; // CPF (só dígitos) para autofill no site
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

class _WebViewScreenState extends State<WebViewScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller =
      widget.prewarmed ?? (WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted));

  int _progress = 0;
  bool _loading = false;
  Timer? _bgTimer;
  bool _openedExternal = false;

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



    // Toda a configuração precisa estar encadeada no _controller.
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)

    // ===== Canal "UI": 'loading:on' / 'loading:off' controla overlay
      ..addJavaScriptChannel('UI', onMessageReceived: (m) {
        final msg = m.message.trim().toLowerCase();
        if (msg == 'loading:on') _showLoading();
        if (msg == 'loading:off') _hideLoading();
      })

    // ===== Canal "Token": salva tokenLogin
      ..addJavaScriptChannel('Token', onMessageReceived: (m) async {
        final token = m.message;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token_login', token);
      })

    // ===== Canal "Downloader": recebe {name,dataUrl(base64)} e abre no app nativo
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

    // ===== Delegate de navegação
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),

          onPageFinished: (_) async {
            await _injectHooks(initialCpf: widget.initialCpf);

            // Tenta ler token do localStorage
            try {
              final result = await _controller.runJavaScriptReturningResult(
                "(() => { try { return localStorage.getItem('tokenLogin') || ''; } catch(e){ return ''; } })();",
              );
              final token = (result is String)
                  ? result.replaceAll('"', '')
                  : (result ?? '').toString();
              if (token.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('token_login', token);
              }
            } catch (_) {}
          },

          onNavigationRequest: (req) async {
            final url = req.url;
            final lower = url.toLowerCase();

            // 1) esquemas externos (tel:, mailto: etc.) -> fora do app
            if (!lower.startsWith('http') ||
                lower.startsWith('tel:') ||
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

            // 2) PDFs explícitos ou endpoints dinâmicos -> intercepta e baixa via fetch
            if (lower.endsWith('.pdf') || _isPdfEndpoint(url)) {
              _showLoading();
              await _downloadPdfThroughWebView(url);
              return NavigationDecision.prevent;
            }

            // 3) demais URLs -> navega normal
            return NavigationDecision.navigate;
          },

          onWebResourceError: (_) => _hideLoading(),
        ),
      )

    // Página inicial
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgTimer?.cancel();
    // (Opcional) deslogar ao sair desta tela:
    // SessionManager.wipeAll(_controller);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bgTimer?.cancel();
      _openedExternal = false;
    }

    if (state == AppLifecycleState.paused) {
      if (_openedExternal) return; // não desloga se abriu app externo/PDF
      _bgTimer?.cancel();
      _bgTimer = Timer(const Duration(minutes: 5), _logoutAndWipe);
    }

    if (state == AppLifecycleState.detached) {
      _logoutAndWipe();
    }
  }

  Future<void> _logoutAndWipe() async {
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

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  Future<void> _injectHooks({String? initialCpf}) async {
    final cpf = (initialCpf ?? '').replaceAll(RegExp(r'\D'), '');

    final js = r"""
(function(){
  if (window.__ipasemHooks) return; window.__ipasemHooks = true;

  function uiOn(){ try { UI.postMessage('loading:on'); } catch(_){} }
  function uiOff(){ try { UI.postMessage('loading:off'); } catch(_){} }

  function fetchPdfToDownloader(u, fallbackName){
    uiOn();
    fetch(u, {
      credentials:'include',
      cache:'no-cache',
      headers:{ 'Accept':'application/pdf,application/octet-stream,*/*' }
    })
    .then(async function(resp){
      var cd = resp.headers.get('content-disposition') || '';
      var filename = fallbackName || (u.split('/').pop() || 'arquivo.pdf');
      try {
        var m = cd.match(/filename\*?=(?:UTF-8''|")?([^\";]+)/i);
        if (m && m[1]) filename = decodeURIComponent(m[1].replace(/\"/g,''));
      } catch(e){}
      var blob = await resp.blob();
      var r = new FileReader();
      r.onloadend = function(){
        Downloader.postMessage(JSON.stringify({ name: filename, dataUrl: r.result }));
      };
      r.readAsDataURL(blob);
    })
    .catch(function(_){ uiOff(); });
  }

  function postFormAndDownload(action, data, useMultipart){
    uiOn();
    if (useMultipart) {
      var fd = new FormData();
      Object.keys(data||{}).forEach(function(k){ fd.append(k, data[k]); });
      fetch(action, { method:'POST', body: fd, credentials:'include' })
        .then(handleResp).catch(function(_){ uiOff(); });
    } else {
      var usp = new URLSearchParams();
      Object.keys(data||{}).forEach(function(k){ usp.append(k, data[k]); });
      fetch(action, {
        method:'POST',
        headers:{'Content-Type':'application/x-www-form-urlencoded;charset=UTF-8'},
        body: usp.toString(),
        credentials:'include'
      }).then(handleResp).catch(function(_){ uiOff(); });
    }
    async function handleResp(resp){
      var cd = resp.headers.get('content-disposition') || '';
      var filename = 'relatorio.pdf';
      try {
        var m = cd.match(/filename\*?=(?:UTF-8''|")?([^\";]+)/i);
        if (m && m[1]) filename = decodeURIComponent(m[1].replace(/\"/g,''));
      } catch(e){}
      var blob = await resp.blob();
      var r = new FileReader();
      r.onloadend = function(){
        Downloader.postMessage(JSON.stringify({ name: filename, dataUrl: r.result }));
      };
      r.readAsDataURL(blob);
    }
  }

  document.querySelectorAll('a[id^="reimpressao-"]').forEach(function(btn){
    if (btn.__hooked) return; btn.__hooked = true;
    btn.addEventListener('click', function(e){
      try{
        var token = localStorage.getItem('tokenLogin') || '';
        if (token) {
          var href = btn.getAttribute('href')||'';
          var sep = href.indexOf('?')>-1 ? '&' : '?';
          if (href.indexOf('token_login=') === -1) {
            href = href + sep + 'token_login=' + encodeURIComponent(token);
            btn.setAttribute('href', href);
          }
        }
        var hrefLow = (btn.getAttribute('href')||'').toLowerCase();
        if (hrefLow.endsWith('.pdf')) { e.preventDefault(); fetchPdfToDownloader(btn.href); return false; }
      }catch(_){}
    }, true);
  });

  document.querySelectorAll('a[href*="imprimir-ordem"]').forEach(function(a){
    if (a.__hooked) return; a.__hooked = true;
    a.addEventListener('click', function(){ uiOn(); setTimeout(uiOff, 20000); }, true);
  });

  var modalBtn = document.getElementById('btn-imprimir-pdf');
  if (modalBtn && !modalBtn.__hooked){
    modalBtn.__hooked = true;
    modalBtn.addEventListener('click', function(){ uiOn(); setTimeout(uiOff, 20000); }, true);
  }

  function hookRelForm(id, multipart){
    var f = document.getElementById(id);
    if (!f || f.__relHook) return; f.__relHook = true;
    f.addEventListener('submit', function(e){
      e.preventDefault();
      var data = {};
      Array.from(f.elements).forEach(function(el){ if(el.name) data[el.name]=el.value; });
      postFormAndDownload(f.action, data, !!multipart);
      return false;
    }, true);
  }
  hookRelForm('form-extrato', false);
  hookRelForm('form-extrato-irpf', false);

  const EP = [
    '/reimpressao/imprimir-segunda-via',
    '/reimpressao/imprimir-autorizacao',
    '/emitir-comprovante',
    '/ordem/historico-pdf',
    '/imprimir-ordem',
  ];
  function isPdfEndpoint(u){ try { return EP.some(p => (u||'').indexOf(p) !== -1); } catch(_) { return false; } }

  document.querySelectorAll('a[href]').forEach(function(a){
    if (a.__pdfHook) return; a.__pdfHook = true;
    a.addEventListener('click', function(e){
      var href = a.href || '';
      var low = href.toLowerCase();
      if (low.endsWith('.pdf') || isPdfEndpoint(href)) {
        e.preventDefault();
        fetchPdfToDownloader(href);
        return false;
      }
    }, true);
  });

  try{
    if (!window.__openPatched){
      window.__openPatched = true;
      var _open = window.open;
      window.open = function(u, n, f){
        try{
          var low = String(u||'').toLowerCase();
          if (low.endsWith('.pdf') || isPdfEndpoint(u)){
            fetchPdfToDownloader(u);
            return null;
          }
        }catch(_){}
        return _open ? _open(u, n, f) : null;
      };
    }
  }catch(_){}

  (function(cpf){
    try{
      if (!cpf) return;
      var fields = Array.from(document.querySelectorAll('input'));
      var targets = [];
      var direct = document.getElementById('loginform-username'); if (direct) targets.push(direct);
      fields.forEach(function(el){
        var id=(el.id||'').toLowerCase(), name=(el.name||'').toLowerCase(), ph=(el.placeholder||'').toLowerCase();
        if (id.includes('cpf')||name.includes('cpf')||ph.includes('cpf')) targets.push(el);
      });
      if (targets.length===0){
        fields.forEach(function(el){
          var t=(el.type||'text').toLowerCase(), m=el.maxLength||el.maxlength||0;
          if ((t==='text'||t==='tel'||t==='number') && (m===11)) targets.push(el);
        });
      }
      targets.forEach(function(el){
        el.focus(); el.value=cpf;
        el.dispatchEvent(new Event('input',{bubbles:true}));
        el.dispatchEvent(new Event('change',{bubbles:true}));
        el.blur();
      });
    }catch(_){}
  })('""" + cpf + r"""');
})();
""";

    await _controller.runJavaScript(js);
  }

  Future<void> _downloadPdfThroughWebView(String url) async {
    final escaped = url.replaceAll("\\", "\\\\").replaceAll("'", r"\'");

    final js = """
      (function(){
        try { UI.postMessage('loading:on'); } catch(e){}
        var url = '$escaped';
        fetch(url, { credentials:'include', cache:'no-cache',
          headers:{ 'Accept':'application/pdf,application/octet-stream,*/*' }})
          .then(async function(resp){
            var cd = resp.headers.get('content-disposition') || '';
            var filename = (url.split('/').pop() || 'arquivo.pdf');
            try {
              var m = cd.match(/filename\\*?=(?:UTF-8''|")?([^\\\";]+)/i);
              if (m && m[1]) filename = decodeURIComponent(m[1].replace(/\\\"/g,''));
            } catch(e){}
            var blob = await resp.blob();
            var r = new FileReader();
            r.onloadend = function(){
              Downloader.postMessage(JSON.stringify({ name: filename, dataUrl: r.result }));
            };
            r.readAsDataURL(blob);
          })
          .catch(function(_){ try { UI.postMessage('loading:off'); } catch(e){} });
      })();
    """;

    await _controller.runJavaScript(js);
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
