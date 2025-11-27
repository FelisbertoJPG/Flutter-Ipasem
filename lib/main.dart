// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'common/certificado/ipasem_http_overrides.dart';
import 'common/config/app_config.dart';
import 'common/config/params.dart';
import 'common/services/api_router.dart';
import 'common/services/polling/exame_bg_worker.dart';
import 'common/state/notification_bridge.dart';
import 'frontend/screens/home_screen.dart';
import 'frontend/screens/home_servicos.dart';
import 'frontend/screens/login_screen.dart';
import 'frontend/screens/privacidade_screen.dart';
import 'frontend/screens/profile_screen.dart';
import 'frontend/screens/sobre_screen.dart';
import 'frontend/screens/termos_screen.dart';
import 'update_enforcer.dart';
import 'animation_warmup.dart';
// IMPORT CONDICIONAL (tem que ficar no TOPO, fora de funções!)
import 'web/webview_initializer_stub.dart'
if (dart.library.html) 'web/webview_initializer_web.dart';
// ==== background polling (workmanager) ====
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:workmanager/workmanager.dart';


// Base prod: por padrão assistweb; pode sobrescrever com --dart-define=API_BASE=...
const String kLocalBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://assistweb.ipasemnh.com.br',
);
// String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.18');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //ignora o https
  HttpOverrides.global = IpasemHttpOverrides();


  // Registra implementação da WebView no Web (no-op nas outras plataformas)
  ensureWebViewRegisteredForWeb();

  // Warm-up do SharedPreferences
  await SharedPreferences.getInstance();

  // Liga o bridge de notificações (idempotente).
  await NotificationBridge.I.attach();

  // Parâmetros do app (sem dados sensíveis) — ponto único da base da API
  final params = AppParams(
    baseApiUrl: kLocalBase,
    passwordMinLength: 4,
    firstAccessUrl: 'https://assistweb.ipasemnh.com.br/site/recuperar-senha',
  );

  // === Fonte única de verdade ===
  ApiRouter.configure(params.baseApiUrl);
  await ApiRouter.persistToPrefs(); // <- garante que o worker verá a mesma base

  // Inicializa e agenda o worker em background (após persistir a base)
  if (!kIsWeb) {
    await Workmanager().initialize(
      exameBgDispatcher, // entrypoint @pragma('vm:entry-point')
      isInDebugMode: kDebugMode,
    );

    await Workmanager().registerPeriodicTask(
      kExameBgUniqueName,                 // uniqueName
      kExameBgUniqueName,                 // taskName
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }

  runApp(
    AppConfig(
      params: params,
      flavor: 'prod', // diferencie dos builds locais nos logs/analytics
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
      builder: (context, child) => AnimationWarmUp(child: child ?? const SizedBox()),
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
  State<LoginSlidesOverSplashLocal> createState() => _LoginSlidesOverSplashLocalState();
}

class _LoginSlidesOverSplashLocalState extends State<LoginSlidesOverSplashLocal>
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
