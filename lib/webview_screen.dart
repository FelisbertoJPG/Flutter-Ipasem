import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Tela genérica de WebView para o app,
/// com suporte a:
/// - Interceptação/Download de PDFs (inclusive endpoints que não terminam com .pdf),
/// - Envio/recebimento de mensagens JS<->Flutter via JavaScriptChannels,
/// - Overlay de loading controlado pelo JS,
/// - Autofill do CPF no formulário do site,
/// - Tratamento do botão "Voltar" (navega primeiro no histórico da WebView).
class WebViewScreen extends StatefulWidget {
  /// URL inicial a ser carregada na WebView.
  final String url;

  /// Título da AppBar (opcional).
  final String? title;

  /// CPF (apenas dígitos) para tentar autofill no site (opcional).
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
  /// Controlador principal da WebView (permite executar JS, navegar, etc).
  late final WebViewController _controller;

  /// Progresso do carregamento da página [0–100].
  int _progress = 0;

  /// Controle do overlay de loading (ativado por mensagens do JS).
  bool _loading = false;

  // ========= Regras para “endpoints dinâmicos” que retornam PDF (sem .pdf no final) =========

  /// Endpoints conhecidos no backend que geram PDF via GET, mas não terminam com .pdf.
  /// Ex.: /reimpressao/imprimir-segunda-via?token=...
  static const List<String> _pdfEndpoints = [
    '/reimpressao/imprimir-segunda-via',
    '/reimpressao/imprimir-autorizacao',
    '/emitir-comprovante',
    '/ordem/historico-pdf',
    '/imprimir-ordem',
  ];

  /// Testa se a URL solicitada bate em algum endpoint que retorna PDF.
  bool _isPdfEndpoint(String url) => _pdfEndpoints.any((e) => url.contains(e));

  /// Mostra overlay de loading.
  void _showLoading() => setState(() => _loading = true);

  /// Esconde overlay de loading.
  void _hideLoading() => setState(() => _loading = false);

  @override
  void initState() {
    super.initState();

    // Configuração do controlador da WebView.
    _controller = WebViewController()
    // Permite execução de JavaScript na página.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)

    // ========== Canal "UI": o JS pede para ligar/desligar o overlay de loading ==========
      ..addJavaScriptChannel('UI', onMessageReceived: (m) {
        final msg = m.message.trim().toLowerCase();
        if (msg == 'loading:on') _showLoading();
        if (msg == 'loading:off') _hideLoading();
      })

    // ========== Canal "Downloader": o JS envia o PDF (como dataURL + nome) para o Flutter abrir ==========
      ..addJavaScriptChannel('Downloader', onMessageReceived: (msg) async {
        try {
          final map = jsonDecode(msg.message) as Map<String, dynamic>;
          final name = (map['name'] as String?)?.trim();
          final dataUrl = map['dataUrl'] as String;

          // Extrai a parte base64 do dataURL.
          final i = dataUrl.indexOf('base64,');
          if (i < 0) throw Exception('DataURL inválido');
          final b64 = dataUrl.substring(i + 7);
          final bytes = base64Decode(b64);

          // Salva o PDF em arquivo temporário e abre com o app nativo de PDF.
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
          _hideLoading();
        }
      })

    // ========== Delegate de navegação: decide se a WebView navega ou se o app intercepta ==========
      ..setNavigationDelegate(
        NavigationDelegate(
          // Atualiza a barra de progresso (0–100).
          onProgress: (p) => setState(() => _progress = p),

          // Ao terminar de carregar, injeta os hooks JS (interceptação de PDF, autofill CPF, etc).
          onPageFinished: (_) async {
            await _injectHooks(initialCpf: widget.initialCpf);
          },

          // Decide a navegação para cada URL antes de carregar.
          onNavigationRequest: (req) async {
            final url = req.url;
            final lower = url.toLowerCase();

            // 1) Links externos (tel:, mailto:, whatsapp:, intent:, etc) → abre fora do app.
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

            // 2) PDFs (termina com .pdf) OU endpoints dinâmicos → intercepta e baixa via fetch no JS.
            if (lower.endsWith('.pdf') || _isPdfEndpoint(url)) {
              _showLoading();
              await _downloadPdfThroughWebView(url); // baixa dentro da própria sessão da WebView
              return NavigationDecision.prevent;      // impede navegação “em branco”/erro
            }

            // 3) Demais casos → segue navegação normal.
            return NavigationDecision.navigate;
          },

          // Qualquer erro de recurso → esconde overlay.
          onWebResourceError: (_) => _hideLoading(),
        ),
      )

    // Carrega a URL inicial.
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Trata o botão "voltar":
  /// - Se a WebView tem histórico, volta uma página ali (sem sair da tela Flutter).
  /// - Se não tem, permite sair da tela Flutter.
  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  /// Injeta um bloco de JavaScript na página com:
  /// - Helpers para ligar/desligar overlay via canal "UI";
  /// - Funções para baixar PDF por GET/POST com `fetch(..., credentials:'include')`;
  /// - Hooks para links/botões/`window.open` que geram PDFs;
  /// - Hooks específicos para formulários de relatório (POST → download);
  /// - Autofill do CPF no input do login (heurística por id/name/placeholder).
  Future<void> _injectHooks({String? initialCpf}) async {
    // Apenas dígitos do CPF (remove pontos/traço/etc).
    final cpf = (initialCpf ?? '').replaceAll(RegExp(r'\D'), '');

    // r""" ... """ → string “raw” (não precisa escapar barras). Concateno o CPF no meio.
    final js = r"""
(function(){
  if (window.__ipasemHooks) return; window.__ipasemHooks = true;

  // ----- Helpers para overlay de loading controlado pelo Flutter -----
  function uiOn(){ try { UI.postMessage('loading:on'); } catch(_){} }
  function uiOff(){ try { UI.postMessage('loading:off'); } catch(_){} }

  // ----- GET de PDF com fetch (mantém cookies HttpOnly da sessão) -----
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

  // ----- POST que retorna PDF (urlencoded por padrão; ative multipart se necessário) -----
  function postFormAndDownload(action, data, useMultipart){
    uiOn();
    if (useMultipart) {
      // multipart/form-data: semelhante ao FormData do browser
      var fd = new FormData();
      Object.keys(data||{}).forEach(function(k){ fd.append(k, data[k]); });
      fetch(action, { method:'POST', body: fd, credentials:'include' })
        .then(handleResp).catch(function(_){ uiOff(); });
    } else {
      // application/x-www-form-urlencoded: compatível com muitos backends PHP
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

  // ========================= Hooks e Integrações com a página =========================

  // 1) “Reimpressão”: anexa token_login do localStorage ao href (se existir)
  //    e, se o href final terminar com .pdf, baixa por fetch imediatamente.
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

  // 2) “Imprimir ordem/autorização”: apenas exibe loading — o fluxo do site segue.
  document.querySelectorAll('a[href*="imprimir-ordem"]').forEach(function(a){
    if (a.__hooked) return; a.__hooked = true;
    a.addEventListener('click', function(){ uiOn(); setTimeout(uiOff, 20000); }, true);
  });

  // 3) Botão de imprimir PDF dentro de modal (se existir): também ativa loading temporário.
  var modalBtn = document.getElementById('btn-imprimir-pdf');
  if (modalBtn && !modalBtn.__hooked){
    modalBtn.__hooked = true;
    modalBtn.addEventListener('click', function(){ uiOn(); setTimeout(uiOff, 20000); }, true);
  }

  // 4) Forms de relatório: intercepta submit, coleta dados, faz POST via fetch e baixa o PDF.
  //    Se algum endpoint exigir multipart, mude o terceiro parâmetro para true.
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

  // 5) Links que geram PDF: tanto .pdf quanto endpoints dinâmicos.
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

  // 6) window.open para .pdf ou endpoints dinâmicos: intercepta e baixa via fetch.
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

  // 7) Autofill do CPF: tenta id/placeholder/name contendo "cpf" e preenche.
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

    // Injeta o JS na página atual.
    await _controller.runJavaScript(js);
  }

  /// Força um GET via fetch (no contexto da própria página) para URLs
  /// que terminam com .pdf ou batem nos endpoints dinâmicos.
  /// Isso garante que os cookies HttpOnly sejam enviados corretamente.
  Future<void> _downloadPdfThroughWebView(String url) async {
    // Escapa barras/aspas para interpolar a URL dentro da string JS.
    final escaped = url.replaceAll("\\", "\\\\").replaceAll("'", r"\'");

    // Script enxuto que faz fetch + envia para o canal "Downloader".
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
    // WillPopScope garante que o “back” navegue primeiro dentro da WebView.
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
            // A própria WebView.
            WebViewWidget(controller: _controller),

            // Barra de progresso fina (0–100).
            if (_progress < 100) LinearProgressIndicator(value: _progress / 100),

            // Overlay de loading: ativado/desativado pelo canal "UI" do JS.
            if (_loading)
              Container(
                color: Colors.black38,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      height: 56,
                      width: 56,
                      child: CircularProgressIndicator(strokeWidth: 5),
                    ),
                    SizedBox(height: 12),
                    Text('Gerando PDF...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
