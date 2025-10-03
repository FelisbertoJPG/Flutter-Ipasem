// lib/ui/utils/service_launcher.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/src/webview_controller.dart';

import '../../webview_screen.dart';
import 'cpf_prompt.dart';

/// Launcher bem simples: só navega para a WebView e,
/// quando necessário, pede o CPF antes.
class ServiceLauncher {
  ServiceLauncher(this.context, WebViewController? Function() takePrewarmed);
  final BuildContext context;

  /// Abre a URL na WebView.
  Future<void> openUrl(String url, String title, {String? cpf}) async {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebViewScreen(
          url: url,
          title: title,
          initialCpf: cpf,
          // removido: preaquecer / prewarmed para simplicidade
        ),
      ),
    );
  }

  /// Mostra o prompt de CPF, salva no SharedPreferences e abre a WebView.
  Future<void> openWithCpfPrompt(
      String url,
      String title, {
        String prefsKeyCpf = 'saved_cpf',
      }) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefsKeyCpf);
    final cpf = await CpfPrompt.show(context, initial: saved);
    if (cpf == null || cpf.isEmpty) return;

    await prefs.setString(prefsKeyCpf, cpf);
    await openUrl(url, title, cpf: cpf);
  }
}
