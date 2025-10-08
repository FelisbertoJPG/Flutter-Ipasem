import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/colors.dart';
import '../root_nav_shell.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool minimal;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.minimal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (minimal) {
      return Scaffold(body: body);
    }

    final inShell = RootNavShell.maybeOf(context) != null;
    final canPopHere = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: inShell
            ? (canPopHere
            ? BackButton(onPressed: () => Navigator.of(context).maybePop())
            : Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ))
            : BackButton(onPressed: () => Navigator.of(context).maybePop()),
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
      // Drawer só no root da shell; em telas empilhadas mostramos "voltar"
      drawer: inShell && !canPopHere ? const _AppDrawer() : null,
      body: body,
    );
  }
}

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

  void _goTab(BuildContext context, int index) {
    Navigator.of(context).pop(); // fecha o drawer
    final shell = RootNavShell.maybeOf(context);
    if (shell != null) {
      shell.setTab(index);
    } else {
      // Fallback: sempre reabre a shell com a aba pedida
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/', (r) => false, arguments: {'tab': index});
    }
  }

  void _goRoute(BuildContext context, String routeName) {
    Navigator.of(context).pop();
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
              child: Text('Menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Início'),
              onTap: () => _goTab(context, 0),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text('Serviços'),
              onTap: () => _goTab(context, 1),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Perfil'),
              onTap: () => _goTab(context, 2),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Sobre'),
              onTap: () => _goRoute(context, '/sobre'),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacidade'),
              onTap: () => _goRoute(context, '/privacidade'),
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
