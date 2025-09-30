// lib/ui/app_shell.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Se você tem seu arquivo de cores centralizado, mantenha este import:
import '../theme/colors.dart'; // exporta kBrand, kCardBg, kCardBorder, kPanelBg, kPanelBorder

/// Scaffold padrão com AppBar + Drawer reaproveitáveis.
/// - Use `minimal: true` para esconder AppBar e Drawer (ex.: Termos/Privacidade abrindo do diálogo)
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool minimal; // <— NOVO

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.minimal = false, // <— NOVO
  });

  @override
  Widget build(BuildContext context) {
    if (minimal) {
      // Sem AppBar, sem Drawer, só o body!
      return Scaffold(body: body);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          const _LogoAction(
            imagePath: 'assets/images/icons/logo_ipasem.png',
            size: 28,
            borderRadius: 6,
          ),
          const SizedBox(width: 8),
          if (actions != null) ...actions!,
        ],
      ),
      drawer: const _AppDrawer(),
      body: body,
    );
  }
}

/// Drawer único para o app inteiro (usa rotas nomeadas)
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  Future<void> _logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_cpf');
      await prefs.remove('auth_token');
      await prefs.setBool('is_logged_in', false);

      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível encerrar a sessão.')),
      );
    }
  }

  void _go(BuildContext context, String routeName) {
    Navigator.of(context).pop(); // fecha o drawer
    if (ModalRoute.of(context)?.settings.name != routeName) {
      Navigator.of(context).pushNamed(routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Text(
                'Menu',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Início'),
              onTap: () => _go(context, '/'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text('Serviços'),
              onTap: () => _go(context, '/servicos'),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Perfil'),
              onTap: () => _go(context, '/perfil'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Sobre'),
              onTap: () => _go(context, '/sobre'),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacidade'),
              onTap: () => _go(context, '/privacidade'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () async {
                Navigator.of(context).pop();
                await _logout(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo da AppBar
class _LogoAction extends StatelessWidget {
  final String imagePath;
  final double size;
  final double borderRadius;

  const _LogoAction({
    super.key,
    required this.imagePath,
    this.size = 28,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
