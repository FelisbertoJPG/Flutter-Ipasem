import 'package:flutter/material.dart';
import 'login.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const splashBg = Color(0xFFFFFFFF); // MESMA cor do splash nativo

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Login Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: splashBg, // evita “flash”
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginSlidesOverSplash(
        splashColor: splashBg,
        splashImage: 'assets/images/icons/splash_logo.png', // MESMA imagem do splash
        durationMs: 420,
      ),
    );
  }
}

/// Mantém o splash parado no fundo e FAZ A LoginPage SUBIR por cima.
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
    begin: const Offset(0, 1), // começa fora da tela (embaixo)
    end: Offset.zero,          // termina ocupando a tela
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  bool _hideSplash = false;

  @override
  void initState() {
    super.initState();
    // Garante primeiro frame e cache da imagem antes de animar.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await precacheImage(AssetImage(widget.splashImage), context);
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      await _c.forward();
      if (mounted) setState(() => _hideSplash = true); // remove splash do tree
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
        // A LoginPage sobe por cima do splash
        Positioned.fill(
          child: ClipRect( // evita desenhar fora da tela durante o slide
            child: SlideTransition(
              position: _slide,
              child: const LoginPage(),
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