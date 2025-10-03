// lib/update_enforcer.dart
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget “wrapper” que checa se há atualização obrigatória na Play Store.
/// - Em **debug/profile**, **Web** e **plataformas ≠ Android**: nunca bloqueia.
/// - Em **Android release**: tenta immediate/flexible update. Se não der e houver
///   atualização disponível, mostra uma tela bloqueando o uso até o usuário atualizar.
class PlayUpdateEnforcer extends StatefulWidget {
  final Widget child;
  const PlayUpdateEnforcer({super.key, required this.child});

  @override
  State<PlayUpdateEnforcer> createState() => _PlayUpdateEnforcerState();
}

class _PlayUpdateEnforcerState extends State<PlayUpdateEnforcer>
    with WidgetsBindingObserver {
  // ---- Estado interno ----
  bool _checking = true;   // indica que estamos verificando atualização
  bool _blocked = false;   // true quando a UI deve bloquear o uso do app
  String _storeUrl = '';   // intent da Play Store (market://)
  String _fallbackUrl = ''; // URL HTTP da Play Store (fallback)

  @override
  void initState() {
    super.initState();
    // Observa ciclo de vida do app (pra re-checar quando voltar do store)
    WidgetsBinding.instance.addObserver(this);
    _checkAndEnforce(); // dispara a primeira checagem
  }

  @override
  void dispose() {
    // Remove o observer ao desmontar o widget
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ciclo de vida do app.
  /// Quando voltamos para o app (resumed) e estamos bloqueados,
  /// disparamos nova checagem (o usuário pode ter atualizado na loja).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _blocked) {
      _checkAndEnforce();
    }
  }

  /// Faz a checagem de atualização e aplica as regras de bloqueio/liberação.
  ///
  /// Fluxo:
  /// 1) Se não for Android release (debug/profile, web, iOS/desktop), libera.
  /// 2) Monta URLs de loja a partir do package name.
  /// 3) Usa `InAppUpdate.checkForUpdate()`:
  ///    - Se houver update:
  ///      a) tenta **Immediate Update** (bloqueante do Google);
  ///      b) se não puder, tenta **Flexible Update** (baixa e finaliza);
  ///      c) se nenhuma for permitida, bloqueia e sugere abrir a loja.
  ///    - Se não houver update: libera.
  /// 4) Qualquer exceção (sem Play Services/sideload/cancelamento): libera.
  Future<void> _checkAndEnforce() async {
    setState(() => _checking = true);

    // Curto-circuito para ambientes de desenvolvimento/teste
    if (!kReleaseMode || kIsWeb || !Platform.isAndroid) {
      setState(() {
        _blocked = false;
        _checking = false;
      });
      return;
    }

    // Monta as URLs da loja com base no package
    final pkg = (await PackageInfo.fromPlatform()).packageName;
    _storeUrl = 'market://details?id=$pkg';
    _fallbackUrl = 'https://play.google.com/store/apps/details?id=$pkg';

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Tenta immediate update (modal oficial do Google)
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          setState(() {
            _blocked = false; // se concluiu, pode liberar
            _checking = false;
          });
          return;
        }

        // Tenta flexible update como alternativa
        if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
          setState(() {
            _blocked = false; // baixou e aplicou
            _checking = false;
          });
          return;
        }

        // Há update, mas nenhum modo permitido -> bloqueia e sugere ir pra loja
        setState(() {
          _blocked = true;
          _checking = false;
        });
        return;
      }

      // Sem update disponível -> libera
      setState(() {
        _blocked = false;
        _checking = false;
      });
    } catch (_) {
      // Qualquer falha ao consultar/atualizar -> não bloqueia o uso
      setState(() {
        _blocked = false;
        _checking = false;
      });
    }
  }

  /// Abre a Play Store.
  /// Tenta primeiro o esquema `market://` (app nativo da loja).
  /// Se não for possível, usa a URL HTTP no navegador.
  Future<void> _openStore() async {
    for (final u in [_storeUrl, _fallbackUrl]) {
      final uri = Uri.parse(u);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
  }

  /// Constrói a UI:
  /// - Enquanto verifica: mostra progress.
  /// - Quando bloqueado: mostra tela de “Atualize para continuar”.
  /// - Senão, renderiza `widget.child`.
  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_blocked) {
      // Tela de bloqueio até atualizar (somente em release+android com update disponível)
      return WillPopScope(
        onWillPop: () async => false, // impede voltar
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.system_update, size: 72),
                      const SizedBox(height: 16),
                      const Text(
                        'Há uma atualização disponível.\nPor favor, atualize para continuar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _openStore,
                          child: const Text('Atualizar na Play Store'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _checkAndEnforce, // re-checa ao voltar do store
                        child: const Text('Já atualizei, verificar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // App liberado
    return widget.child;
  }
}
