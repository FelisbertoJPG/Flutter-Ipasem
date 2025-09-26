// lib/home_servicos.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'webview_screen.dart';
import 'login_screen.dart'; // apenas se o Drawer tiver "Sair" (logout)

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
    // HTML mínimo para pré-aquecer o engine
    _warmupCtrl.loadHtmlString('<html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head><body></body></html>');

    // Insere WebView invisível após o primeiro frame
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
      final overlay = Overlay.of(context, rootOverlay: true);
      if (overlay != null) {
        overlay.insert(_warmupOverlay!);
      }
    });
  }

  @override
  void dispose() {
    // remove overlay se existir
    _warmupOverlay?.remove();
    _warmupOverlay = null;
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
      // ===== AppBar com hambúrguer e logo no canto (como no ProfileScreen) =====
      appBar: AppBar(

        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: const [
          _LogoAction(
            imagePath: 'assets/images/icons/logo_ipasem.png',
            size: 28,
            borderRadius: 6,
          ),
          SizedBox(width: 8),
        ],
      ),

      // ===== Drawer padrão (ajuste conteúdos conforme seu app) =====
      drawer: const _AppDrawer(),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Padding base adaptativo: levemente maior em telas grandes
            final horizontal = constraints.maxWidth >= 640 ? 24.0 : 16.0;
            final verticalTop = 16.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(horizontal, verticalTop, horizontal, 24),
                  children: [
                    // ===== Painel acinzentado com os botões dentro =====
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
            );
          },
        ),
      ),
    );
  }
}

// ===== Drawer básico (ajuste itens conforme necessidade) =====
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  Future<void> _logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_cpf');
      await prefs.remove('auth_token');
      await prefs.setBool('is_logged_in', false);

      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível encerrar a sessão.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Text(
                'Menu',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Sobre'),
            ),
            const ListTile(
              leading: Icon(Icons.privacy_tip_outlined),
              title: Text('Privacidade'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () async {
                Navigator.of(context).pop(); // fecha o drawer
                await _logout(context);
              },
            ),
          ],
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
      minimumSize: const Size.fromHeight(64), // levemente menor para telas pequenas
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

/// Ação de AppBar que garante que qualquer imagem seja contida no quadrado,
/// recortada sem deformar (BoxFit.cover + ClipRRect).
class _LogoAction extends StatelessWidget {
  final String imagePath;
  final double size;
  final double borderRadius;

  const _LogoAction({
    super.key,
    required this.imagePath,
    this.size = 28,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
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
        // Altura mínima segura mesmo em telas pequenas
        final sheetHeight = media.size.height * 0.30; // um pouco maior, melhora teclado landscape

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
            height: sheetHeight.clamp(260.0, 420.0),
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
                          if (ctx.mounted) {
                            Navigator.pop(ctx, digits);
                          }
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

  if (!context.mounted) return;
  // abre a WebView com CPF para autofill
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
