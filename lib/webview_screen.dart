// lib/webview_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services/pdf_controller.dart';

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
  final _pdf = PdfController();
  int _progress = 0;
  bool _loading = false;

  void _showLoading() => setState(() => _loading = true);
  void _hideLoading() => setState(() => _loading = false);

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Android', onMessageReceived: (m) {
        if (m.message.startsWith('showLoading')) _showLoading();
        if (m.message.startsWith('hideLoading')) _hideLoading();
      })
      ..addJavaScriptChannel('Pdf', onMessageReceived: (m) async {
        // payload: {"method":"GET"|"POST","url":"...","data":{"k":"v"},"multipart":false}
        try {
          final map = jsonDecode(m.message) as Map<String, dynamic>;
          final method = (map['method'] as String).toUpperCase();
          final url = map['url'] as String;
          final multipart = (map['multipart'] as bool?) ?? false;
          final data = (map['data'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? <String,String>{};

          _showLoading();
          if (method == 'GET') {
            await _pdf.handlePdfGet(url, _controller);
          } else if (method == 'POST') {
            if (multipart) {
              await _pdf.handlePdfPostMultipart(url, Map<String,String>.from(data), _controller);
            } else {
              await _pdf.handlePdfPostUrlEncoded(url, Map<String,String>.from(data), _controller);
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF erro: $e')));
          }
        } finally {
          _hideLoading();
        }
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onPageFinished: (url) async {
            await _injectHooks(initialCpf: widget.initialCpf);
          },
          onNavigationRequest: (req) async {
            final url = req.url.toLowerCase();
            // esquemas externos
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
            // .pdf direto → GET via controller
            if (url.endsWith('.pdf')) {
              _showLoading();
              await _pdf.handlePdfGet(req.url, _controller);
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
  if (window.__ipasem) return; window.__ipasem = true;

  // Android.showLoading/hideLoading
  if (!window.Android) window.Android = {};
  Android.showLoading = function(){ try{ Android.postMessage('showLoading'); }catch(e){} };
  Android.hideLoading = function(){ try{ Android.postMessage('hideLoading'); }catch(e){} };

  // Envia instruções de PDF ao Flutter
  function pdfGet(url){ Pdf.postMessage(JSON.stringify({method:'GET', url:url})); }
  function pdfPostUrlEncoded(url, data){ Pdf.postMessage(JSON.stringify({method:'POST', url:url, data:data, multipart:false})); }
  function pdfPostMultipart(url, data){ Pdf.postMessage(JSON.stringify({method:'POST', url:url, data:data, multipart:true})); }

  // Reimpressão: anexa token_login de localStorage e mostra loading
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
      }catch(_){}
      Android.showLoading();
    }, true);
  });

  // Imprimir ordem/autorização
  document.querySelectorAll('a[href*="imprimir-ordem"]').forEach(function(a){
    if (a.__hooked) return; a.__hooked = true;
    a.addEventListener('click', function(){ Android.showLoading(); }, true);
  });

  // Botão modal imprimir PDF
  var modalBtn = document.getElementById('btn-imprimir-pdf');
  if (modalBtn && !modalBtn.__hooked){
    modalBtn.__hooked = true;
    modalBtn.addEventListener('click', function(){ Android.showLoading(); }, true);
  }

  // Forms normais → loading
  document.querySelectorAll('form').forEach(function(f){
    if (f.__hooked) return; f.__hooked = true;
    f.addEventListener('submit', function(){ Android.showLoading(); }, true);
  });

  // Selects específicos → loading
  ['#especialidade','#cidade','.prestador','.dependente'].forEach(function(sel){
    document.querySelectorAll(sel).forEach(function(el){
      if (el.__hooked) return; el.__hooked = true;
      el.addEventListener('change', function(){ Android.showLoading(); }, true);
    });
  });

  // --- FORM RELATÓRIOS (POST para Flutter) ---
  function hookRelForm(id){
    var f = document.getElementById(id);
    if (!f || f.__relHook) return; f.__relHook = true;
    f.addEventListener('submit', function(e){
      e.preventDefault();
      Android.showLoading();
      var data = {};
      Array.from(f.elements).forEach(function(el){ if(el.name) data[el.name]=el.value; });
      // Primeiro tente urlencoded (compatível com a maioria dos backends PHP)
      pdfPostUrlEncoded(f.action, data);
      return false;
    }, true);
  }
  hookRelForm('form-extrato');
  hookRelForm('form-extrato-irpf');

  // Links .pdf → GET via controller
  document.querySelectorAll('a[href$=".pdf"]').forEach(function(a){
    if (a.__pdfHook) return; a.__pdfHook = true;
    a.addEventListener('click', function(e){
      e.preventDefault();
      Android.showLoading();
      pdfGet(a.href);
      return false;
    }, true);
  });

  // window.open para .pdf
  try{
    if (!window.__openPatched){
      window.__openPatched = true;
      var _open = window.open;
      window.open = function(u, n, f){
        try{
          if (typeof u === 'string' && u.toLowerCase().endsWith('.pdf')){
            Android.showLoading();
            pdfGet(u);
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
              color: Colors.black26,
              alignment: Alignment.center,
              child: const SizedBox(
                height: 64, width: 64, child: CircularProgressIndicator(strokeWidth: 4),
              ),
            ),
        ],
      ),
    );
  }
}
