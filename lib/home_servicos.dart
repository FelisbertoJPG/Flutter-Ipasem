import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'webview_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

//Todo: Problema com a Geração do Email

// === Cores padronizadas ===
const _cardBg    = Color(0xFFEFF6F9); // mesma cor do Card-logo
const _cardBorder= Color(0xFFE2ECF2); // mesma borda usada nos cards
const _brand     = Color(0xFF143C8D); // azul dos ícones/textos


// Home: serviços rápidos do app
class HomeServicos extends StatefulWidget {
  const HomeServicos({super.key});

  static const String _prefsKeyCpf = 'saved_cpf';
  static const String _loginUrl = 'https://assistweb.ipasemnh.com.br/site/login';

  // contatos
  static const String _tel = 'tel:5135949162';

  @override
  State<HomeServicos> createState() => _HomeServicosState();
}

class _HomeServicosState extends State<HomeServicos> {
  // WebView pré-aquecida (primeira navegação mais rápida)
  late final WebViewController _warmupCtrl =
  WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
  OverlayEntry? _warmupOverlay;
  bool _usedWarmup = false;

  @override
  void initState() {
    super.initState();
    _warmupCtrl.loadHtmlString('<html><body></body></html>');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmupOverlay = OverlayEntry(
        builder: (_) => IgnorePointer(
          child: Opacity(
            opacity: 0,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 1,
                height: 1,
                child: WebViewWidget(controller: _warmupCtrl),
              ),
            ),
          ),
        ),
      );
      Overlay.of(context, rootOverlay: true).insert(_warmupOverlay!);
    });
  }

  @override
  void dispose() {
    _warmupOverlay?.remove();
    super.dispose();
  }

  // Reusa a WebView pré-aquecida no primeiro push
  void _openWeb(BuildContext context,
      {required String url, required String title, String? cpf}) {
    final prewarmed = _usedWarmup ? null : _warmupCtrl;

    if (!_usedWarmup) {
      _warmupOverlay?.remove();
      _warmupOverlay = null;
    }
    _usedWarmup = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(_softSlideRoute(
        WebViewScreen(url: url, title: title, initialCpf: cpf, prewarmed: prewarmed),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = <_Service>[
      _Service('Autorização de Exames', Icons.how_to_reg_outlined, _Action.cpfThenWeb,
          url: HomeServicos._loginUrl),


      _Service('Site', Icons.public_outlined, _Action.web,
          url: 'https://www.ipasemnh.com.br/home'),

      // novo card único de contatos
      _Service('Contatos', Icons.support_agent_outlined, _Action.contacts),
    ];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const _LogoBanner(),
                const SizedBox(height: 20),

                // barras compridas com sombra
                ...services.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _LongActionButton(
                    title: s.title,
                    icon: s.icon,
                    onTap: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        switch (s.action) {
                          case _Action.web:
                            _openWeb(context, url: s.url!, title: s.title);
                            break;
                          case _Action.cpfThenWeb:
                            await _promptCpfAndOpen(context,
                                url: s.url!, title: s.title);
                            break;
                          case _Action.contacts:
                            await _showContactsSheet(context);
                            break;
                        }
                      });
                    },
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Action { web, cpfThenWeb, contacts }

class _Service {
  final String title;
  final IconData icon;
  final _Action action;
  final String? url;
  const _Service(this.title, this.icon, this.action, {this.url});
}

// Botão comprido com ícone à esquerda, título centralizado e sombra
// --- ajuste no widget do botão ---
class _LongActionButton extends StatelessWidget {
  final String title;
  final IconData icon;          // fallback se "leading" for nulo
  final Widget? leading;        // pode ser FaIcon, etc.
  final bool showNew;
  final VoidCallback onTap;

  // Tamanhos
  final double height;          // altura do botão
  final double iconSize;        // tamanho do ícone
  final double fontSize;        // tamanho do texto

  // >>> NOVOS parâmetros de borda
  final double borderWidth;
  final Color borderColor;

  const _LongActionButton({
    required this.title,
    required this.icon,
    required this.onTap,
    this.leading,
    this.showNew = false,
    this.height = 56,
    this.iconSize = 22,
    this.fontSize = 16,
    this.borderWidth = 2,              // <<< mais forte
    this.borderColor = _cardBorder,    // <<< mantém a mesma cor da UI
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: Ink(
        decoration: BoxDecoration(
          color: _cardBg, // mantém a cor dos botões
          borderRadius: radius,
          border: Border.all(color: borderColor, width: borderWidth), // <<< aqui
          boxShadow: const [
            BoxShadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x14000000)),
          ],
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 12),
                    IconTheme.merge(
                      data: IconThemeData(size: iconSize, color: _brand),
                      child: leading ?? Icon(icon),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Center(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: fontSize,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Opacity(opacity: 0, child: Icon(Icons.circle, size: iconSize)),
                    const SizedBox(width: 12),
                  ],
                ),
                if (showNew)
                  Positioned(
                    top: 6, left: 8,
                    child: Row(
                      children: [
                        SizedBox(width: 10, height: 10,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                        ),
                        const SizedBox(width: 6),
                        const Text('NOVIDADE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _LogoBanner extends StatelessWidget {
  const _LogoBanner();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: const Color(0xFFEFF6F9),
          alignment: Alignment.center,
          child: Image.asset(
            'assets/images/icons/logo_ipasem.png',
            height: 72,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
Future<void> _goEmail(BuildContext context) async {
  final mail = Uri(
    scheme: 'mailto',
    path: 'contato@ipasemnh.com.br',
    queryParameters: const {
      'subject': 'Atendimento IPASEM',
      'body': '',
    },
  );

  // 1) Tenta abrir em app de e-mail
  try {
    if (await canLaunchUrl(mail)) {
      final ok = await launchUrl(mail, mode: LaunchMode.externalApplication);
      if (ok) return;
    }
  } catch (_) {}

  // 2) Fallback: Gmail web compose (abre no navegador logado)
  final gmailWeb = Uri.https('mail.google.com', '/mail/', {
    'view': 'cm',
    'fs': '1',
    'to': 'contato@ipasemnh.com.br',
    'su': 'Atendimento IPASEM',
    'body': '',
  });

  if (await canLaunchUrl(gmailWeb)) {
    await launchUrl(gmailWeb, mode: LaunchMode.externalApplication);
    return;
  }

  // 3) Último recurso: copia o e-mail e avisa
  await Clipboard.setData(const ClipboardData(text: 'contato@ipasemnh.com.br'));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Nenhum app de e-mail encontrado. Endereço copiado.')),
    //TODO: Ta caindo aqui o erro
  );
}

// Bottom-sheet de contatos (Ligar / E-mail)
Future<void> _showContactsSheet(BuildContext context) async {
  Future<void> _go(String raw) async {
    final uri = Uri.parse(raw);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE5EE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Contatos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.call_outlined),
                title: const Text('Ligar'),
                onTap: () {
                  Navigator.pop(ctx);
                  _go(HomeServicos._tel);
                },
              ),
              ListTile(
                leading: const Icon(Icons.alternate_email_outlined),
                title: const Text('Enviar E-mail'),
                onTap: () {
                  Navigator.pop(ctx);
                  _goEmail(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

// Prompt de CPF (mantido)
Future<void> _promptCpfAndOpen(BuildContext context,
    {required String url, required String title}) async {
  final ctrl = TextEditingController();
  final focus = FocusNode();
  String? error;
  var didInit = false;

  final cpf = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        if (!didInit) {
          didInit = true;
          Future.microtask(() async {
            final prefs = await SharedPreferences.getInstance();
            final saved = prefs.getString(HomeServicos._prefsKeyCpf) ?? '';
            if (saved.isNotEmpty) {
              ctrl.text = saved;
              setState(() {});
            }
          });
          Future.delayed(const Duration(milliseconds: 180), () {
            if (focus.canRequestFocus) focus.requestFocus();
          });
        }

        final media = MediaQuery.of(ctx);
        final sheetHeight = media.size.height * 0.25;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: media.viewInsets.bottom + 16,
          ),
          child: SizedBox(
            height: sheetHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE5EE),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Insira seu CPF',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  focusNode: focus,
                  autofocus: false,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    hintText: '00000000000',
                    errorText: error,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final digits = ctrl.text.replaceAll(RegExp(r'\D'), '');
                          if (digits.length != 11) {
                            setState(() => error = 'CPF deve ter 11 dígitos');
                            return;
                          }
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString(HomeServicos._prefsKeyCpf, digits);
                          Navigator.pop(ctx, digits);
                        },
                        child: const Text('Continuar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      });
    },
  );

  if (cpf == null || cpf.isEmpty) return;

  // abre a WebView com CPF para autofill
  // ignore: use_build_context_synchronously
  Navigator.of(context).push(_softSlideRoute(
    WebViewScreen(url: url, title: title, initialCpf: cpf),
  ));
}

Route<T> _softSlideRoute<T>(Widget page, {int durationMs = 360}) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration(milliseconds: durationMs),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(a),
          child: child,
        ),
      );
    },
  );
}