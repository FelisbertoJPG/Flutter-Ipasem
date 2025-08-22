import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';


/// Controla toda a ponte JS <-> Flutter pra deixar a tela enxuta.
class IpasemJs {
  /// Injeta todos os hooks (interceptação de PDF, overlay, autofill CPF, etc).
  static Future<void> injectInto(WebViewController c, {String? cpf}) async {
    final onlyDigits = (cpf ?? '').replaceAll(RegExp(r'\D'), '');

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

  // Reimpressão: injeta token_login e intercepta .pdf
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

  // Overlay “visual” em alguns botões
  document.querySelectorAll('a[href*="imprimir-ordem"]').forEach(function(a){
    if (a.__hooked) return; a.__hooked = true;
    a.addEventListener('click', function(){ uiOn(); setTimeout(uiOff, 20000); }, true);
  });
  var modalBtn = document.getElementById('btn-imprimir-pdf');
  if (modalBtn && !modalBtn.__hooked){
    modalBtn.__hooked = true;
    modalBtn.addEventListener('click', function(){ uiOn(); setTimeout(uiOff, 20000); }, true);
  }

  // Formulários de relatório
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

  // Interceptação genérica de PDF/endpoints
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
  })('""" + onlyDigits + r"""');
})();
""";

    await c.runJavaScript(js);
  }

  /// Força download do PDF dentro do contexto da página (leva cookies).
  static Future<void> downloadThroughWebView(
      WebViewController c,
      String url,
      ) async {
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
    await c.runJavaScript(js);
  }

  /// Lê o token do localStorage.
  static Future<String?> readToken(WebViewController c) async {
    try {
      final r = await c.runJavaScriptReturningResult(
        "(() => { try { return localStorage.getItem('tokenLogin') || ''; } catch(e){ return ''; } })();",
      );
      final token = (r is String) ? r.replaceAll('"', '') : (r ?? '').toString();
      return token.isEmpty ? null : token;
    } catch (_) {
      return null;
    }
  }

}


