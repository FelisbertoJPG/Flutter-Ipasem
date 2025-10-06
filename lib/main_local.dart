// lib/main_local.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'config/params.dart';
import 'update_enforcer.dart';
import 'animation_warmup.dart';

// TELAS
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/home_servicos.dart';
import 'screens/sobre_screen.dart';
import 'screens/privacidade_screen.dart';
import 'screens/termos_screen.dart';

// IMPORT CONDICIONAL (tem que ficar no TOPO, fora de funções!)
import 'web/webview_initializer_stub.dart'
if (dart.library.html) 'web/webview_initializer_web.dart';

// Base local: por padrão .18; pode sobrescrever com --dart-define=API_BASE=http://host
const String kLocalBase =
String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://assistweb.ipasemnh.com.br',
);
//String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.18');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Registra implementação da WebView no Web (no-op nas outras plataformas)
  ensureWebViewRegisteredForWeb();

  // Warm-up do SharedPreferences
  await SharedPreferences.getInstance();

  // Parâmetros do app (sem dados sensíveis) — ponto único da base da API
  final params = AppParams(
    baseApiUrl: kLocalBase, // <- Só o 18 por padrão
    passwordMinLength: 4,
    firstAccessUrl: 'https://assistweb.ipasemnh.com.br/site/recuperar-senha',
  );

  runApp(
    AppConfig(
      params: params,
      flavor: 'local',
      child: const MyAppLocal(),
    ),
  );
}

class MyAppLocal extends StatelessWidget {
  const MyAppLocal({super.key});
  static const splashBg = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IpasemNH (Local)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: splashBg,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF143C8D)),
        fontFamily: 'Roboto',
      ),
      // Suaviza as primeiras animações
      builder: (context, child) =>
          AnimationWarmUp(child: child ?? const SizedBox()),
      initialRoute: '/__splash_login',
      routes: {
        '/__splash_login': (_) => const _SplashRouteWrapper(),
        '/':            (_) => const HomeScreen(),
        '/login':       (_) => const LoginScreen(),
        '/perfil':      (_) => const ProfileScreen(),
        '/servicos':    (_) => const HomeServicos(),
        '/sobre':       (_) => const SobreScreen(),
        '/privacidade': (_) => const PrivacidadeScreen(),
        '/termos':      (_) => const TermosScreen(),
      },
    );
  }
}

/// Envelopa o splash com o enforcer
class _SplashRouteWrapper extends StatelessWidget {
  const _SplashRouteWrapper();

  @override
  Widget build(BuildContext context) {
    return PlayUpdateEnforcer(
      child: const LoginSlidesOverSplashLocal(
        splashColor: MyAppLocal.splashBg,
        splashImage: 'assets/images/icons/splash_logo.png',
        durationMs: 420,
      ),
    );
  }
}

class LoginSlidesOverSplashLocal extends StatefulWidget {
  final Color splashColor;
  final String splashImage;
  final int durationMs;

  const LoginSlidesOverSplashLocal({
    super.key,
    required this.splashColor,
    required this.splashImage,
    this.durationMs = 420,
  });

  @override
  State<LoginSlidesOverSplashLocal> createState() =>
      _LoginSlidesOverSplashLocalState();
}

class _LoginSlidesOverSplashLocalState
    extends State<LoginSlidesOverSplashLocal>
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
              child: Image.asset(
                widget.splashImage,
                width: 180,
                fit: BoxFit.contain,
              ),
            ),
          ),
        Positioned.fill(
          child: ClipRect(
            child: SlideTransition(
              position: _slide,
              child: const LoginScreen(),
            ),
          ),
        ),
      ],
    );
  }
}
