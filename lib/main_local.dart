// lib/main_local.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'config/params.dart';
import 'update_enforcer.dart';
import 'animation_warmup.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance(); // pré-aquecimento do prefs

  // Parâmetros locais (seu "params-local")
  const localParams = AppParams(
    adminEmail: 'admin@example.com',
    supportEmail: 'ipasem-naoresponder@ipasemnh.com.br',
    senderEmail:  'ipasem-naoresponder@ipasemnh.com.br',
    senderName:   'IpasemNH mailer',
    passwordResetTokenExpire: Duration(seconds: 3600),
    passwordMinLength: 8,
    baseApiUrl: 'http://10.0.2.2:8080/api', // emulador -> localhost do host
  );


  runApp(
    AppConfig(
      params: localParams,
      flavor: 'local',
      child: const MyAppLocal(), // app igual ao do main.dart
    ),
  );
}

/// Versão local do seu MyApp (mesma estrutura do main.dart)
class MyAppLocal extends StatelessWidget {
  const MyAppLocal({super.key});
  static const splashBg = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IpasemNH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: splashBg,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF143C8D)),
      ),
      builder: (context, child) =>
          AnimationWarmUp(child: child ?? const SizedBox()),
      home: PlayUpdateEnforcer(
        child: const LoginSlidesOverSplashLocal(
          splashColor: MyAppLocal.splashBg,
          splashImage: 'assets/images/icons/splash_logo.png',
          durationMs: 420,
        ),
      ),
    );
  }
}

/// Copiado do seu main.dart (renomeado para evitar conflitos)
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
              child: Image.asset(widget.splashImage, width: 180, fit: BoxFit.contain),
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
