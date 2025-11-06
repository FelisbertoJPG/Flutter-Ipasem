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

    // Dentro da RootNavShell?
    final shell = RootNavShell.maybeOf(context);
    final inShell = shell != null;

    // Nome da rota atual (definido pela shell nas abas raiz)
    final routeName = ModalRoute.of(context)?.settings.name ?? '';

    // Conjunto de rotas RAIZ das abas (nessas, queremos SEMPRE hambúrguer)
    const tabRoots = {'home-root', 'servicos-root', 'perfil-root'};
    final isTabRoot = inShell && tabRoots.contains(routeName);

    // Pode dar pop neste Navigator local?
    final canPopHere = Navigator.of(context).canPop();

    // Regra final: mostra "voltar" apenas se NÃO for raiz de aba
    final showBack = !inShell || (!isTabRoot && canPopHere);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(title),
        leading: showBack
            ? BackButton(
          onPressed: () {
            // Back centralizado (se estiver na Shell)
            final scope = RootNavShell.maybeOf(context);
            if (scope != null) {
              scope.safeBack(); // ignorar Future é ok aqui
            } else {
              Navigator.of(context).maybePop();
            }
          },
        )
            : Builder(
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
      // Drawer só aparece no root das abas
      drawer: isTabRoot ? const _AppDrawer() : null,
      body: body,
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  Future<void> _logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Flag “manter login” (se não existir, default true)
      final remember = prefs.getBool('remember_login') ?? true;

      // Sempre encerra a sessão
      await prefs.setBool('is_logged_in', false);
      await prefs.remove('auth_token');

      // Só limpa credenciais se NÃO quiser manter login
      if (!remember) {
        await prefs.remove('saved_cpf');
        await prefs.remove('saved_pwd');
        await prefs.remove('saved_password');
      }

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/login', (route) => false);
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
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/', (r) => false, arguments: {'tab': index});
    }
  }

  void _goRoute(BuildContext context, String routeName) {
    // Fecha o Drawer e empurra a rota no Navigator raiz
    Navigator.of(context).pop();
    final shell = RootNavShell.maybeOf(context);

    if (shell != null) {
      // Usa o helper exposto pela Shell (abre fora das abas)
      shell.pushRootNamed(routeName);
    } else {
      // Fallback direto no rootNavigator
      Future.microtask(() {
        Navigator.of(context, rootNavigator: true).pushNamed(routeName);
      });
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
