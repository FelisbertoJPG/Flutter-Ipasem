import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String? title;
  const WebViewScreen({super.key, required this.url, this.title});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))

    // Canal para receber PDFs (dataURL) do JS
      ..addJavaScriptChannel(
        'Downloader',
        onMessageReceived: (msg) async {
          // payload: {"name":"arquivo.pdf","dataUrl":"data:application/pdf;base64,...."}
          final map = jsonDecode(msg.message) as Map<String, dynamic>;
          final name = (map['name'] as String?)?.trim();
          final dataUrl = map['dataUrl'] as String;
          await _saveAndOpenDataUrl(dataUrl, suggestedName: name);
        },
      )

      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),

          // Intercepta links diretos para .pdf
          onNavigationRequest: (req) async {
            final url = req.url.toLowerCase();

            // Esquemas especiais -> abre fora
            if (!url.startsWith('http') ||
                url.startsWith('tel:') ||
                url.startsWith('mailto:') ||
                url.startsWith('whatsapp:') ||
                url.startsWith('intent:')) {
              final uri = Uri.parse(req.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              }
            }

            // Link direto para PDF: baixa via fetch dentro da WebView,
            // preservando cookies (credentials: 'include')
            if (url.endsWith('.pdf')) {
              await _downloadPdfThroughWebView(req.url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Falha ao carregar: ${error.errorCode}')),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // Injeta scripts quando a página termina, para capturar os formulários de relatório
  Future<void> _injectFormHooks() async {
    const js = r"""
    (function() {
      function hookForm(formId) {
        var f = document.getElementById(formId);
        if (!f) return;

        if (f.__hooked) return; // evita hook duplicado
        f.__hooked = true;

        f.addEventListener('submit', function(e) {
          e.preventDefault();
          var fd = new FormData(f);

          fetch(f.action, {
            method: 'POST',
            body: fd,
            credentials: 'include' // usa cookies da sessão da WebView
          })
          .then(async function(resp) {
            var cd = resp.headers.get('content-disposition') || '';
            var filename = 'relatorio.pdf';
            try {
              var m = cd.match(/filename\*?=(?:UTF-8''|")?([^\";]+)/i);
              if (m && m[1]) filename = decodeURIComponent(m[1].replace(/\"/g,''));
            } catch (e) {}

            var blob = await resp.blob();
            var reader = new FileReader();
            reader.onloadend = function() {
              // Envia para o Flutter: name + dataUrl (base64)
              Downloader.postMessage(JSON.stringify({
                name: filename,
                dataUrl: reader.result
              }));
            };
            reader.readAsDataURL(blob); // -> data:application/pdf;base64,....
          })
          .catch(function(err) {
            console.error('Erro ao baixar PDF:', err);
          });

          return false;
        }, true);
      }

      // IDs usados no site
      hookForm('form-extrato');
      hookForm('form-extrato-irpf');

      // Também intercepta cliques em <a href="*.pdf">
      document.querySelectorAll('a[href$=".pdf"]').forEach(function(a){
        if (a.__hooked) return;
        a.__hooked = true;
        a.addEventListener('click', function(e){
          e.preventDefault();
          var url = a.href;
          fetch(url, { credentials:'include' })
          .then(async function(resp){
            var cd = resp.headers.get('content-disposition') || '';
            var filename = (url.split('/').pop() || 'arquivo.pdf');
            try {
              var m = cd.match(/filename\*?=(?:UTF-8''|")?([^\";]+)/i);
              if (m && m[1]) filename = decodeURIComponent(m[1].replace(/\"/g,''));
            } catch(e){}

            var blob = await resp.blob();
            var reader = new FileReader();
            reader.onloadend = function(){
              Downloader.postMessage(JSON.stringify({
                name: filename,
                dataUrl: reader.result
              }));
            };
            reader.readAsDataURL(blob);
          });
        }, true);
      });
    })();
    """;
    await _controller.runJavaScript(js);
  }

  // Se um link .pdf passar pelo NavigationDelegate, força o fetch via JS (mantendo cookies)
  Future<void> _downloadPdfThroughWebView(String url) async {
    final escaped = url.replaceAll("\\", "\\\\").replaceAll("'", r"\'");
    final js = """
      (function(){
        var url = '$escaped';
        fetch(url, { credentials:'include' })
          .then(async function(resp){
            var cd = resp.headers.get('content-disposition') || '';
            var filename = (url.split('/').pop() || 'arquivo.pdf');
            try {
              var m = cd.match(/filename\\*?=(?:UTF-8''|")?([^\\\";]+)/i);
              if (m && m[1]) filename = decodeURIComponent(m[1].replace(/\\\"/g,''));
            } catch(e){}

            var blob = await resp.blob();
            var reader = new FileReader();
            reader.onloadend = function(){
              Downloader.postMessage(JSON.stringify({
                name: filename,
                dataUrl: reader.result
              }));
            };
            reader.readAsDataURL(blob);
          })
          .catch(function(err){ console.error(err); });
      })();
    """;
    await _controller.runJavaScript(js);
  }

  // Salva o dataURL em arquivo temporário e abre no visualizador do sistema
  Future<void> _saveAndOpenDataUrl(String dataUrl, {String? suggestedName}) async {
    try {
      final i = dataUrl.indexOf('base64,');
      if (i < 0) throw Exception('Formato inválido');
      final b64 = dataUrl.substring(i + 7);
      final bytes = base64Decode(b64);

      final dir = await getTemporaryDirectory();
      final safeName = (suggestedName?.isNotEmpty == true ? suggestedName! : 'documento.pdf')
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(bytes);

      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Navegador')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // re-injeta hooks quando necessário (após primeira navegação)
    _injectFormHooks();
  }
}
