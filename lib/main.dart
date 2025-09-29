// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'update_enforcer.dart';
import 'animation_warmup.dart';
import 'root_nav_shell.dart'; // << usa o shell com BottomNav + Drawer (mantido se for usado após login)

// [CONFIG] Imports para configuração
import 'config/app_config.dart';
import 'config/params.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance(); // pré-aquecimento do prefs

  // [CONFIG] Carrega parâmetros a partir de --dart-define
  final params = AppParams.fromEnv();

  // [CONFIG] Define o flavor conforme seu processo (ajuste se desejar)
  const flavor = String.fromEnvironment('APP_FLAVOR', defaultValue: 'prod');

  runApp(
    // [CONFIG] Injeta AppConfig no topo da árvore
    AppConfig(
      params: params,
      flavor: flavor,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const splashBg = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    // [CONFIG] Exemplo: acesso aos params se precisar configurar tema/rotas por ambiente
    // final cfg = AppConfig.of(context);
    // debugPrint('Flavor: ${cfg.flavor}, supportEmail: ${cfg.params.supportEmail}');

    return MaterialApp(
      title: 'IpasemNH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, // NavigationBar (Material 3)
        scaffoldBackgroundColor: splashBg,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF143C8D)),
      ),
      // injeta o warm-up de animação DENTRO do MaterialApp
      builder: (context, child) =>
          AnimationWarmUp(child: child ?? const SizedBox()),
      home: PlayUpdateEnforcer(
        child: const LoginSlidesOverSplash(
          splashColor: MyApp.splashBg,
          splashImage: 'assets/images/icons/splash_logo.png',
          durationMs: 420,
        ),
      ),
    );
  }
}

class LoginSlidesOverSplash extends StatefulWidget {
  final Color splashColor;
  final String splashImage;
  final int durationMs;

  const LoginSlidesOverSplash({
    super.key,
    required this.splashColor,
    required this.splashImage,
    this.durationMs = 420,
  });

  @override
  State<LoginSlidesOverSplash> createState() => _LoginSlidesOverSplashState();
}

class _LoginSlidesOverSplashState extends State<LoginSlidesOverSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: Duration(milliseconds: widget.durationMs));
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  bool _hideSplash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await precacheImage(AssetImage(widget.splashImage), context);
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      await _c.forward();
      if (mounted) setState(() => _hideSplash = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (!_hideSplash)
          Positioned.fill(
            child: Container(
              color: widget.splashColor,
              alignment: Alignment.center,
              child: Image.asset(widget.splashImage, width: 180, fit: BoxFit.contain),
            ),
          ),
        Positioned.fill(
          child: ClipRect(
            child: SlideTransition(
              position: _slide,
              // >> AQUI: após o splash, entra a tela inicial (LoginScreen, que depois pode navegar ao RootNavShell)
              child: const LoginScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

Route<T> slideUpRoute<T>(Widget page, {int durationMs = 420}) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration(milliseconds: durationMs),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final offset = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved);
      return SlideTransition(position: offset, child: child);
    },
  );
}
