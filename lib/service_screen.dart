import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'webview_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ====== Paleta / estilos base ======
const _brand       = Color(0xFF143C8D); // azul da marca (ícones/títulos)
const _cardBg      = Color(0xFFEFF6F9); // fundo dos botões
const _cardBorder  = Color(0xFFE2ECF2); // borda clarinha dos botões
const _panelBg     = Color(0xFFF4F5F7); // fundo do painel acinzentado
const _panelBorder = Color(0xFFE5E8EE); // borda do painel acinzentado

class HomeServicos extends StatefulWidget {
  const HomeServicos({super.key});

  static const String _prefsKeyCpf    = 'saved_cpf';
  static const String _loginUrl       = 'https://assistweb.ipasemnh.com.br/site/login';
  static const String _carteirinhaUrl = 'https://assistweb.ipasemnh.com.br/site/login'; // TODO: ajustar quando tiver a URL

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
                        iconColor: Colors.red,
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
                        iconColor: Colors.green,
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

// ====== Botão largo com cara de botão (ElevatedButton) ======
class _WideServiceButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _WideServiceButton({
    required this.title,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  ButtonStyle _style(BuildContext context) {
    Color overlay(Set<MaterialState> s) {
      if (s.contains(MaterialState.pressed)) return _brand.withOpacity(0.08);
      if (s.contains(MaterialState.hovered)) return _brand.withOpacity(0.04);
      return Colors.transparent;
    }

    double elevation(Set<MaterialState> s) {
      if (s.contains(MaterialState.pressed)) return 2;
      return 1;
    }

    return ElevatedButton.styleFrom(
      elevation: 0,
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _cardBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: iconColor ?? _brand),
          ),
          const SizedBox(width: 12),
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
