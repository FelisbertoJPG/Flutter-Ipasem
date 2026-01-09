// lib/services/session_manager.dart
import 'package:webview_flutter/webview_flutter.dart';

class SessionManager {
  static final _cookieManager = WebViewCookieManager();

  /// Limpa todos os cookies (inclui HttpOnly).
  static Future<void> clearCookies() => _cookieManager.clearCookies();

  /// Limpa o cache da WebView (scripts, html, etc).
  static Future<void> clearCache(WebViewController controller) =>
      controller.clearCache();

  /// Limpa storages da página (localStorage, sessionStorage, caches).
  static Future<void> clearWebStorage(WebViewController controller) async {
    const js = r'''
      (function(){
        try{ localStorage.clear(); }catch(e){}
        try{ sessionStorage.clear(); }catch(e){}
        try{
          if (window.caches) {
            caches.keys().then(keys => keys.forEach(k => caches.delete(k)));
          }
        }catch(e){}
      })();
    ''';
    try { await controller.runJavaScript(js); } catch (_) {}
  }

  /// “Apaga tudo” que mantém a sessão.
  static Future<void> wipeAll(WebViewController controller) async {
    // Ordem não importa muito; rodamos todos em paralelo.
    await Future.wait([
      clearCache(controller),
      clearWebStorage(controller),
      clearCookies(),
    ]);
  }
}
