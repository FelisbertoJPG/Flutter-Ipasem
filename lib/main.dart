// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'update_enforcer.dart';
import 'home_servicos.dart';
import 'animation_warmup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance(); // pré-aquecimento do prefs
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const splashBg = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IpasemNH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: splashBg,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // ⬇️ AQUI: injeta o warm-up de animação DENTRO do MaterialApp
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
              child: const HomeServicos(),
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
//