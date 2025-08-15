import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
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

  const WebViewScreen({
    super.key,
    required this.url,
    this.title,
    this.initialCpf,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with WidgetsBindingObserver { // Observa mudanças no ciclo de vida do app

  // Controlador da WebView para executar JS, navegar, etc.
  late final WebViewController _controller;

  // Progresso da navegação [0–100] para mostrar a barrinha de progresso
  int _progress = 0;

  // Flag do overlay de loading (ligado/desligado pelo JS via canal "UI")
  bool _loading = false;

  // (Opcional) Endpoint de logout do site (POST com fallback em GET)
  static const String _logoutUrl =
      'https://assistweb.ipasemnh.com.br/site/logout';

  // Endpoints “dinâmicos” que retornam PDF via GET mas não terminam com .pdf
  static const List<String> _pdfEndpoints = [
    '/reimpressao/imprimir-segunda-via',
    '/reimpressao/imprimir-autorizacao',
    '/emitir-comprovante',
    '/ordem/historico-pdf',
    '/imprimir-ordem',
  ];

  // Checa se a URL contém algum dos endpoints dinâmicos de PDF
  bool _isPdfEndpoint(String url) => _pdfEndpoints.any((e) => url.contains(e));

  // Liga/desliga overlay de loading
  void _showLoading() => setState(() => _loading = true);
  void _hideLoading() => setState(() => _loading = false);

  @override
  void initState() {
    super.initState();

    // Começa a observar ciclo de vida (para limpar sessão em pause/detach)
    WidgetsBinding.instance.addObserver(this);

    // Configuração do controlador
    _controller = WebViewController()
    // Libera JavaScript
      ..setJavaScriptMode(JavaScriptMode.unrestricted)

    // ===== Canal "UI": o JS manda 'loading:on' / 'loading:off' para controlar overlay
      ..addJavaScriptChannel('UI', onMessageReceived: (m) {
        final msg = m.message.trim().toLowerCase();
        if (msg == 'loading:on') _showLoading();
        if (msg == 'loading:off') _hideLoading();
      })

    // ===== Canal "Downloader": o JS envia {name,dataUrl} (PDF em base64) para o Flutter salvar/abrir
      ..addJavaScriptChannel('Downloader', onMessageReceived: (msg) async {
        try {
          // Decodifica o JSON recebido do JS
          final map = jsonDecode(msg.message) as Map<String, dynamic>;
          final name = (map['name'] as String?)?.trim();
          final dataUrl = map['dataUrl'] as String;

          // Extrai a parte base64 do dataURL
          final i = dataUrl.indexOf('base64,');
          if (i < 0) throw Exception('DataURL inválido');
          final b64 = dataUrl.substring(i + 7);
          final bytes = base64Decode(b64);

          // Salva como arquivo temporário (nome sanitizado) e abre no app nativo de PDF
          final dir = await getTemporaryDirectory();
          final safeName = (name?.isNotEmpty == true ? name! : 'documento.pdf')
              .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

          final file = File('${dir.path}/$safeName');
          await file.writeAsBytes(bytes);
          await OpenFilex.open(file.path);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Falha ao abrir PDF: $e')),
            );
          }
        } finally {
          _hideLoading(); // Sempre esconder overlay no fim do fluxo
        }
      })

    // ===== Delegate de navegação: decide se navega normal ou se intercepta (PDF, links externos, etc.)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Atualiza a UI do progresso
          onProgress: (p) => setState(() => _progress = p),

          // Ao terminar de carregar, injeta os hooks JS (interceptação, autofill, etc.)
          onPageFinished: (_) async {
            await _injectHooks(initialCpf: widget.initialCpf);
          },

          // Decide se bloqueia ou permite a navegação de uma URL
          onNavigationRequest: (req) async {
            final url = req.url;
            final lower = url.toLowerCase();

            // 1) Esquemas externos (tel:, mailto:, whatsapp:, intent:, etc.) → abre fora do app
            if (!lower.startsWith('http') ||
                lower.startsWith('tel:') ||
                lower.startsWith('mailto:') ||
                lower.startsWith('whatsapp:') ||
                lower.startsWith('intent:')) {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent; // cancela navegação interna
              }
            }

            // 2) PDFs (termina com .pdf) OU endpoints dinâmicos → intercepta e baixa via fetch no contexto da página
            if (lower.endsWith('.pdf') || _isPdfEndpoint(url)) {
              _showLoading();
              await _downloadPdfThroughWebView(url); // baixa com cookies HttpOnly
              return NavigationDecision.prevent;      // não deixa a WebView “ir” pra URL direta
            }

            // 3) Qualquer outra URL → navega normal
            return NavigationDecision.navigate;
          },

          // Em qualquer erro de recurso, esconde overlay de loading
          onWebResourceError: (_) => _hideLoading(),
        ),
      )

    // Carrega a página inicial
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    // Para de observar ciclo de vida
    WidgetsBinding.instance.removeObserver(this);
    // Limpa sessão (cookies/cache/storage). Sem await pois dispose não é async.
    SessionManager.wipeAll(_controller);
    super.dispose();
  }

  /// Observa mudanças no ciclo de vida do app:
  /// • paused/detached → tenta deslogar no servidor e limpa sessão local
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _logoutAndWipe();
    }
  }

  /// Faz logout no servidor (POST com fallback em GET) e limpa cookies/cache/storage.
  /// Rodamos o fetch **dentro** do contexto da página para levar cookies HttpOnly.
  Future<void> _logoutAndWipe() async {
    try {
      await _controller.runJavaScript(r'''
        (async function(){
          try{
            await fetch("''' + _logoutUrl + r'''", {method:'POST', credentials:'include'});
          }catch(e){
            try{ await fetch("''' + _logoutUrl + r'''", {credentials:'include'}); }catch(_){}
          }
          try{ localStorage.clear(); }catch(_){}
          try{ sessionStorage.clear(); }catch(_){}
          try{
            if (window.caches){
              const ks = await caches.keys();
              ks.forEach(k => caches.delete(k));
            }
          }catch(_){}
        })();
      ''');
    } catch (_) {
      // Ignora erros do JS/fetch — limpeza nativa logo abaixo garante “deslogado”
    }

    // Limpeza nativa (cookies/cache) para garantir logout local
    await SessionManager.wipeAll(_controller);
  }

  /// Botão “voltar”: prioriza histórico da WebView; se não houver, sai da tela Flutter
  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false; // impede Navigator.pop()
    }
    return true; // permite Navigator.pop()
  }

  /// Injeta hooks JS:
  /// • UI.on/off (overlay)
  /// • fetch GET/POST para baixar PDFs mantendo cookies
  /// • Intercepta links, window.open, reimpressão, formulários de relatório
  /// • Autofill de CPF (heurística em id/name/placeholder)
  Future<void> _injectHooks({String? initialCpf}) async {
    final cpf = (initialCpf ?? '').replaceAll(RegExp(r'\D'), ''); // só dígitos

    // String raw r"""...""" evita ter que escapar barras.
    final js = r"""
(function(){
  if (window.__ipasemHooks) return; window.__ipasemHooks = true;

  // Overlay via canal "UI"
  function uiOn(){ try { UI.postMessage('loading:on'); } catch(_){} }
  function uiOff(){ try { UI.postMessage('loading:off'); } catch(_){} }

  // GET de PDF com fetch (cookies HttpOnly via credentials:'include')
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

  // POST que retorna PDF (urlencoded por padrão; setar multipart=true se precisar)
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

  // Reimpressão: injeta token_login (se existir) e baixa se o href final terminar em .pdf
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

  // Ações de imprimir ordem/autorização: overlay “visual” (navegação segue pelo site)
  document.querySelectorAll('a[href*="imprimir-ordem"]').forEach(function(a){
    if (a.__hooked) return; a.__hooked = true;
    a.addEventListener('click', function(){ uiOn(); setTimeout(uiOff, 20000); }, true);
  });

  // Botão modal "imprimir PDF" (se existir): overlay temporário
  var modalBtn = document.getElementById('btn-imprimir-pdf');
  if (modalBtn && !modalBtn.__hooked){
    modalBtn.__hooked = true;
    modalBtn.addEventListener('click', function(){ uiOn(); setTimeout(uiOff, 20000); }, true);
  }

  // Formulários de relatório: intercepta submit, coleta dados e faz POST → download
  // (se algum for multipart, trocar false → true)
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

  // Intercepta links que geram PDF (.pdf e endpoints dinâmicos) e baixa via fetch
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

  // Intercepta window.open para .pdf/endpoints e baixa via fetch
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

  // Autofill do CPF: tenta por id/name/placeholder contendo "cpf" (ou heurística por maxlength=11)
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

    // Executa o JS na página atual
    await _controller.runJavaScript(js);
  }

  /// Força um GET via fetch quando a navegação tenta abrir .pdf/endpoint dinâmico.
  /// Fazemos no contexto da página para levar cookies da sessão.
  Future<void> _downloadPdfThroughWebView(String url) async {
    // Escapa aspas/barras para interpolar com segurança dentro do JS
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
    // WillPopScope: garante que “back” volte no histórico da WebView antes de sair da tela
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? 'Navegador'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canLeave = await _handleBack();
              if (canLeave && mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            //barra de progresso
            if (_progress < 100) LinearProgressIndicator(value: _progress / 100),

            // Overlay de loading (“Gerando PDF...”), controlado pelo canal "UI"
            if (_loading)
              const IpasemAlertOverlay(
                message: 'PDF sendo gerado, aguarde...',
                type: IpasemAlertType.loading,
                showProgress: true,
                badgeVariant: IpasemBadgeVariant.printLike,
                badgeRadius: 22,     // ↓ menor que 28
                badgeIconSize: 18,   // ↓ ajusta o “i”
              ),

          ],
        ),
      ),
    );
  }
}
