import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'webview_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ====== Paleta / estilos base ======
const _brand       = Color(0xFF143C8D); // azul da marca (ícones/títulos)
const _cardBg      = Color(0xFFEFF6F9); // fundo dos botões
const _cardBorder  = Color(0xFFE2ECF2); // borda clarinha dos botões
const _panelBg     = Color(0xFFF4F5F7); // fundo do painel acinzentado
const _panelBorder = Color(0xFFE5E8EE); // borda do painel acinzentado

// Cores das redes
const _instagramColor = Color(0xFFE1306C);
const _youtubeColor   = Color(0xFFFF0000);

class HomeServicos extends StatefulWidget {
  const HomeServicos({super.key});

  static const String _prefsKeyCpf    = 'saved_cpf';
  static const String _loginUrl       = 'https://assistweb.ipasemnh.com.br/site/login';
  static const String _carteirinhaUrl = 'https://assistweb.ipasemnh.com.br/site/login'; // TODO: ajustar quando tiver a URL

  // contatos
  static const String _tel = 'tel:5135949162';

  // redes sociais
  static const String _instagramUrl = 'https://www.instagram.com/ipasem.nh/';
  static const String _youtubeUrl   = 'https://www.youtube.com/ipasemnh';

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
  void _openWeb(BuildContext context, {required String url, required String title, String? cpf}) {
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
    const saudacao = 'Olá! "Usuario"';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const _LogoBanner(),
                const SizedBox(height: 12),

                // Saudação
                Text(
                  saudacao,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),

                // ====== Painel acinzentado com os botões dentro ======
                Container(
                  decoration: BoxDecoration(
                    color: _panelBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _panelBorder, width: 2),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Serviços em destaque!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475467),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _WideServiceButton(
                        title: 'Autorizações',
                        icon: FontAwesomeIcons.fileMedical,
                        onTap: () async {
                          await _promptCpfAndOpen(
                            context,
                            url: HomeServicos._loginUrl,
                            title: 'Autorizações',
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _WideServiceButton(
                        title: 'Carteirinha Digital',
                        icon: FontAwesomeIcons.idCard,
                        onTap: () {
                          _openWeb(
                            context,
                            url: HomeServicos._carteirinhaUrl,
                            title: 'Carteirinha Digital',
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _WideServiceButton(
                        title: 'Site',
                        icon: FontAwesomeIcons.globe,
                        onTap: () {
                          _openWeb(
                            context,
                            url: 'https://www.ipasemnh.com.br/home',
                            title: 'Site',
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _WideServiceButton(
                        title: 'Contatos',
                        icon: FontAwesomeIcons.headset,
                        onTap: () async {
                          await _showContactsSheet(context);
                        },
                      ),
                    ],
                  ),
                ),

                // ====== Redes sociais ======
                const SizedBox(height: 20),
                _SocialLinks(
                  onInsta: () => _launchExternal(HomeServicos._instagramUrl, context),
                  onYoutube: () => _launchExternal(HomeServicos._youtubeUrl, context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====== Botão largo com cara de botão (ElevatedButton) ======
class _WideServiceButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _WideServiceButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  ButtonStyle _style(BuildContext context) {
    // Estados (hover/pressed/focused)
    Color overlay(Set<MaterialState> s) {
      if (s.contains(MaterialState.pressed)) {
        return _brand.withOpacity(0.08);
      }
      if (s.contains(MaterialState.hovered)) {
        return _brand.withOpacity(0.04);
      }
      return Colors.transparent;
    }

    double elevation(Set<MaterialState> s) {
      if (s.contains(MaterialState.pressed)) return 2;
      return 1; // leve, só pra cara de botão
    }

    return ElevatedButton.styleFrom(
      elevation: 0, // base zero; controlamos via .copyWith
      backgroundColor: _cardBg,
      foregroundColor: const Color(0xFF101828),
      minimumSize: const Size.fromHeight(68),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _cardBorder, width: 2),
      ),
      shadowColor: Colors.black12,
    ).copyWith(
      overlayColor: MaterialStateProperty.resolveWith(overlay),
      elevation: MaterialStateProperty.resolveWith(elevation),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: _style(context),
      onPressed: onTap,
      child: Row(
        children: [
          // Leading “pílula” branca com borda
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _cardBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: _brand),
          ),
          const SizedBox(width: 12),

          // Título (não quebra, vira reticências)
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF101828),
              ),
            ),
          ),

          // Chevron para reforçar affordance de botão
          const Icon(Icons.chevron_right, color: _brand),
        ],
      ),
    );
  }
}

// ====== Banner do logo ======
class _LogoBanner extends StatelessWidget {
  const _LogoBanner();

  static const double _h = 110; // altura do banner

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: _cardBg,
          alignment: Alignment.center,
          child: Image.asset(
            'assets/images/icons/logo_ipasem.png',
            height: _h * 0.55,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

// ====== Redes sociais (menores + mais espaçadas) ======
class _SocialLinks extends StatelessWidget {
  final VoidCallback onInsta;
  final VoidCallback onYoutube;

  const _SocialLinks({required this.onInsta, required this.onYoutube});

  @override
  Widget build(BuildContext context) {
    // ajuste rápido aqui:
    const side      = 60.0; // tamanho do quadrado
    const iconSize  = 24.0; // tamanho do ícone
    const gap       = 25.0; // espaçamento entre eles s

    return Center(
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          _SocialSquareButton(
            color: _instagramColor,
            icon: FontAwesomeIcons.instagram,
            onTap: onInsta,
            size: side,
            iconSize: iconSize,
            semanticLabel: 'Abrir Instagram do IPASEM',
          ),
          _SocialSquareButton(
            color: _youtubeColor,
            icon: FontAwesomeIcons.youtube,
            onTap: onYoutube,
            size: side,
            iconSize: iconSize,
            semanticLabel: 'Abrir YouTube do IPASEM',
          ),
        ],
      ),
    );
  }
}


class _SocialSquareButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final String semanticLabel;

  const _SocialSquareButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.size,
    required this.iconSize,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    Color overlay(Set<MaterialState> s) {
      if (s.contains(MaterialState.pressed)) return Colors.black.withOpacity(0.12);
      if (s.contains(MaterialState.hovered)) return Colors.black.withOpacity(0.08);
      return Colors.transparent;
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: radius),
            elevation: 0,
            padding: EdgeInsets.zero,
          ).copyWith(
            overlayColor: MaterialStateProperty.resolveWith(overlay),
          ),
          onPressed: onTap,
          child: Icon(icon, size: iconSize, color: Colors.white),
        ),
      ),
    );
  }
}


// Botão preenchido (ícone + texto + chevron)
class _SocialFilledButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final double height;
  final double iconSize;

  const _SocialFilledButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.height = 56,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    Color overlay(Set<MaterialState> s) {
      if (s.contains(MaterialState.pressed)) return Colors.black.withOpacity(0.10);
      if (s.contains(MaterialState.hovered)) return Colors.black.withOpacity(0.06);
      return Colors.transparent;
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: Size.fromHeight(height),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        shadowColor: Colors.transparent,
      ).copyWith(
        overlayColor: MaterialStateProperty.resolveWith(overlay),
      ),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: iconSize),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  final double size;
  final double iconSize;
  final Color color;

  const _SocialIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 44,
    this.iconSize = 20,
    this.color = _brand,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _cardBorder, width: 2),
            borderRadius: BorderRadius.circular(size / 2),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }
}

// ====== Contatos: liga / e-mail ======
Future<void> _showContactsSheet(BuildContext context) async {
  Future<void> _goTel(String raw) async {
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
                  _goTel(HomeServicos._tel);
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

// ====== E-mail com fallback robusto (mailto -> Gmail web -> copiar) ======
Future<void> _goEmail(BuildContext context) async {
  final mail = Uri(
    scheme: 'mailto',
    path: 'contato@ipasemnh.com.br',
    queryParameters: const {
      'subject': 'Atendimento IPASEM',
      'body': 'Olá, preciso de ajuda no app.',
    },
  );

  try {
    final opened = await launchUrl(mail, mode: LaunchMode.externalApplication);
    if (opened) return;
  } catch (e) {
    debugPrint('mailto launch error: $e');
  }

  final gmailWeb = Uri.https('mail.google.com', '/mail/', {
    'view': 'cm',
    'fs': '1',
    'to': 'contato@ipasemnh.com.br',
    'su': 'Atendimento IPASEM',
    'body': 'Olá, preciso de ajuda no app.',
  });

  try {
    final openedWeb = await launchUrl(gmailWeb, mode: LaunchMode.externalApplication);
    if (openedWeb) return;
  } catch (e) {
    debugPrint('gmail web launch error: $e');
  }

  await Clipboard.setData(const ClipboardData(text: 'contato@ipasemnh.com.br'));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Nenhum app de e-mail encontrado. Endereço copiado.')),
  );
}

// ====== Abre URL externa genérica ======
Future<void> _launchExternal(String url, BuildContext context) async {
  final uri = Uri.parse(url);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('launch falhou');
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Não foi possível abrir: $url')),
    );
  }
}

// ====== Prompt de CPF ======
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

// ====== Transição suave ======
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
