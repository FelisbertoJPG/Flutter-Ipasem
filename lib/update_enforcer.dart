import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PlayUpdateEnforcer extends StatefulWidget {
  final Widget child;
  const PlayUpdateEnforcer({super.key, required this.child});

  @override
  State<PlayUpdateEnforcer> createState() => _PlayUpdateEnforcerState();
}

class _PlayUpdateEnforcerState extends State<PlayUpdateEnforcer>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _blocked = false;
  String _storeUrl = '';
  String _fallbackUrl = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndEnforce();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Se o user voltar do Play, checa de novo
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _blocked) {
      _checkAndEnforce();
    }
  }

  Future<void> _checkAndEnforce() async {
    setState(() { _checking = true; });

    // monta as URLs da loja a partir do package name
    final pkg = (await PackageInfo.fromPlatform()).packageName;
    _storeUrl   = 'market://details?id=$pkg';
    _fallbackUrl = 'https://play.google.com/store/apps/details?id=$pkg';

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Modo "immediate": bloqueia o app até atualizar
        await InAppUpdate.performImmediateUpdate();
        // se concluir, segue o app
        setState(() { _blocked = false; _checking = false; });
        return;
      }
      // sem update disponível
      setState(() { _blocked = false; _checking = false; });
    } catch (_) {
      // Falha (sideload, sem Play Services, ou user cancelou a tela): bloqueia manualmente
      setState(() { _blocked = true; _checking = false; });
    }
  }

  Future<void> _openStore() async {
    for (final u in [_storeUrl, _fallbackUrl]) {
      final uri = Uri.parse(u);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_blocked) {
      // Tela de bloqueio total até atualizar
      return WillPopScope(
        onWillPop: () async => false,
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
                        'Aplicativo com versão inferior.\nPor favor, atualize na loja para continuar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity, height: 48,
                        child: ElevatedButton(
                          onPressed: _openStore,
                          child: const Text('Atualizar na Play Store'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _checkAndEnforce, // tentar novamente ao voltar
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

    return widget.child; // liberado
  }
}
