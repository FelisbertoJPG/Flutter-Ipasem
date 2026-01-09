import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


mixin WebViewWarmup<T extends StatefulWidget> on State<T> {
  late final WebViewController warmupCtrl =
  WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
  OverlayEntry? _warmupOverlay;
  bool _usedWarmup = false;

  void warmupInit() async{
    if (kIsWeb) return; // no-op no Web
    warmupCtrl.loadHtmlString(
      '<html><head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head><body></body></html>',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmupOverlay = OverlayEntry(
        builder: (_) => IgnorePointer(
          child: Opacity(
            opacity: 0,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 1, height: 1, child: WebViewWidget(controller: warmupCtrl)),
            ),
          ),
        ),
      );
      final overlay = Overlay.of(context, rootOverlay: true);
      overlay?.insert(_warmupOverlay!);
    });
  }

  WebViewController? takePrewarmed() {
    if (_usedWarmup) return null;
    _usedWarmup = true;
    _warmupOverlay?.remove();
    _warmupOverlay = null;
    return warmupCtrl;
  }

  @override
  void dispose() {
    _warmupOverlay?.remove();
    _warmupOverlay = null;
    super.dispose();
  }
}

Route<T> softSlideRoute<T>(Widget page, {int durationMs = 360}) {
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
