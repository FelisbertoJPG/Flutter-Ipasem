import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String? title;
  final String? initialCpf;

  const WebViewScreen({
    super.key,
    required this.url,
    this.title,
    this.initialCpf,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _loading = false;

  void _showLoading() => setState(() => _loading = true);
  void _hideLoading() => setState(() => _loading = false);
  // Endpoints que retornam PDF via GET
  static const List<String> _pdfEndpoints = [
    '/reimpressao/imprimir-segunda-via',
    '/reimpressao/imprimir-autorizacao',
    '/emitir-comprovante',
    '/ordem/historico-pdf',
    '/imprimir-ordem',
  ];

  bool _isPdfEndpoint(String url) =>
      _pdfEndpoints.any((e) => url.contains(e));

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)

    // Canal para ligar/desligar overlay a partir do JS
      ..addJavaScriptChannel('UI', onMessageReceived: (m) {
        final msg = m.message.trim().toLowerCase();
        if (msg == 'loading:on') _showLoading();
        if (msg == 'loading:off') _hideLoading();
      })

    // Canal que recebe o PDF (dataURL + filename) e abre
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
          await OpenFilex.open(file.path);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Falha ao abrir PDF: $e')));
          }
        } finally {
          _hideLoading();
        }
      })

      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),

          // injeta hooks SEMPRE ao terminar
          onPageFinished: (_) async {
            await _injectHooks(initialCpf: widget.initialCpf);
          },

          // links externos e .pdf direto
          onNavigationRequest: (req) async {
            final url = req.url;
            final lower = url.toLowerCase();

            // esquemas externos
            if (!lower.startsWith('http') ||
                lower.startsWith('tel:') ||
                lower.startsWith('mailto:') ||
                lower.startsWith('whatsapp:') ||
                lower.startsWith('intent:')) {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              }
            }

            // .pdf DIRETO ou endpoint que gera PDF → baixa via fetch
            if (lower.endsWith('.pdf') || _isPdfEndpoint(url)) {
              _showLoading();
              await _downloadPdfThroughWebView(url);
              _hideLoading();
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },


          onWebResourceError: (_) => _hideLoading(),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _injectHooks({String? initialCpf}) async {
    final cpf = (initialCpf ?? '').replaceAll(RegExp(r'\\D'), '');

    final js = r"""
(function(){
  if (window.__ipasemHooks) return; window.__ipasemHooks = true;

  // ===== UI helpers (sem Android.*) =====
  function uiOn(){ try { UI.postMessage('loading:on'); } catch(_){} }
  function uiOff(){ try { UI.postMessage('loading:off'); } catch(_){} }

  // baixa um PDF com fetch e manda ao Flutter via Downloader
  function fetchPdfToDownloader(u, fallbackName){
    uiOn();
    fetch(u, { credentials:'include' })
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

  // POST de formulário (urlencoded por padrão). Se precisar multipart, troque.
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

  // ========== Hooks (baseado no teu Java) ==========
  // Reimpressão: anexa token_login e tenta baixar via GET se o alvo for PDF
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

  // Imprimir ordem/autorização (apenas liga loading; o request real vai pelo navegador)
  document.querySelectorAll('a[href*="imprimir-ordem"]').forEach(function(a){
    if (a.__hooked) return; a.__hooked = true;
    a.addEventListener('click', function(){ uiOn(); setTimeout(uiOff, 20000); }, true);
  });

  // Botão modal imprimir PDF
  var modalBtn = document.getElementById('btn-imprimir-pdf');
  if (modalBtn && !modalBtn.__hooked){
    modalBtn.__hooked = true;
    modalBtn.addEventListener('click', function(){ uiOn(); setTimeout(uiOff, 20000); }, true);
  }

  // Forms de relatório: POST -> baixa PDF
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

  // Links .pdf → GET via fetch
  document.querySelectorAll('a[href$=".pdf"]').forEach(function(a){
    if (a.__pdfHook) return; a.__pdfHook = true;
    a.addEventListener('click', function(e){
      e.preventDefault();
      fetchPdfToDownloader(a.href);
      return false;
    }, true);
  });

  // window.open(.pdf)
  try{
    if (!window.__openPatched){
      window.__openPatched = true;
      var _open = window.open;
      window.open = function(u, n, f){
        try{
          if (typeof u === 'string' && u.toLowerCase().endsWith('.pdf')){
            fetchPdfToDownloader(u);
            return null;
          }
        }catch(_){}
        return _open ? _open(u, n, f) : null;
      };
    }
  }catch(_){}

  // Autofill CPF
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

  // Força um GET de PDF via fetch (mantém cookies) quando a navegação tenta abrir .pdf
  Future<void> _downloadPdfThroughWebView(String url) async {
    final escaped = url.replaceAll("\\", "\\\\").replaceAll("'", r"\'");
    final js = """
      (function(){
        try { UI.postMessage('loading:on'); } catch(e){}
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Navegador')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_progress < 100) const LinearProgressIndicator(),
          if (_loading)
            Container(
              color: Colors.black38,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(height: 56, width: 56, child: CircularProgressIndicator(strokeWidth: 5)),
                  SizedBox(height: 12),
                  Text('Gerando PDF...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
