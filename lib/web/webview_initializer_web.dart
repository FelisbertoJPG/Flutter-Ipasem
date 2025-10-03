library webview_initializer_web;

import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';

/// Registra a implementação Web do webview_flutter quando rodando no Web.
/// Deve ser chamada no início do app (ex.: em main()).
void ensureWebViewRegisteredForWeb() {
  // Seta apenas se ainda não estiver configurado
  if (WebViewPlatform.instance is! WebWebViewPlatform) {
    WebViewPlatform.instance = WebWebViewPlatform();
  }
}
