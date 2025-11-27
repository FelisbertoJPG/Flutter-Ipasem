// lib/ui/app_shell.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/config/app_config.dart';
import '../../root_nav_shell.dart';
import '../theme/colors.dart';
import 'components/noticias_banner_strip.dart';

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

  /// Monta a URL do feed de notícias a partir da base configurada no AppConfig.
  /// Aqui fazemos o roteamento "especial" para o banner, conforme o ambiente.
  String _buildNoticiasFeedUrl(BuildContext context) {
    final config = AppConfig.of(context);
    final base = config.params.baseApiUrl.trim();

    if (base.isEmpty) return '';

    Uri uri;
    try {
      uri = Uri.parse(base);
    } catch (_) {
      return '';
    }

    final host = uri.host.toLowerCase();
    final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';

    // === CASOS ESPECÍFICOS ===

    // Dev/homolog local: API em 192.9.200.98, mas banner no :81
    if (host == '192.9.200.98') {
      return Uri(
        scheme: scheme,
        host: '192.9.200.98',
        port: 81,
        path: '/app-banner/banner-app',
      ).toString();
    }

    // Produção: API no assistweb, banner no site público ipasemnh
    if (host == 'assistweb.ipasemnh.com.br') {
      return Uri(
        scheme: 'https',
        host: 'www.ipasemnh.com.br',
        path: '/app-banner/banner-app',
      ).toString();
    }

    // Caso a base já seja ipasemnh.com.br (ex.: build web apontando direto pra lá)
    if (host == 'ipasemnh.com.br' || host == 'www.ipasemnh.com.br') {
      return Uri(
        scheme: uri.scheme.isNotEmpty ? uri.scheme : 'https',
        host: 'www.ipasemnh.com.br',
        path: '/app-banner/banner-app',
      ).toString();
    }

    // === FALLBACK GENÉRICO ===
    // Usa o mesmo host/porta da API e só força o path do banner.
    return uri.replace(
      path: '/app-banner/banner-app',
      query: null,
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    if (minimal) {
      return Scaffold(body: body);
    }

    final shell = RootNavShell.maybeOf(context);
    final inShell = shell != null;

    final routeName = ModalRoute.of(context)?.settings.name ?? '';

    const tabRoots = {'home-root', 'servicos-root', 'perfil-root'};
    final isTabRoot = inShell && tabRoots.contains(routeName);

    final canPopHere = Navigator.of(context).canPop();

    final showBack = !inShell || (!isTabRoot && canPopHere);

    // Usa a mesma base do main/main_local, com regras especiais pro banner.
    final noticiasFeedUrl = _buildNoticiasFeedUrl(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        title: Text(title),
        leading: showBack
            ? BackButton(
          onPressed: () {
            final scope = RootNavShell.maybeOf(context);
            if (scope != null) {
              scope.safeBack();
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
            size: 70,
            borderRadius: 6,
            verticalPadding: 8,
          ),
          const SizedBox(width: 8),
          if (actions != null) ...actions!,
        ],
      ),

      // Drawer só nas roots das abas
      drawer: isTabRoot
          ? _AppDrawer(
        noticiasFeedUrl: noticiasFeedUrl,
      )
          : null,

      body: body,
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final String noticiasFeedUrl;

  const _AppDrawer({
    this.noticiasFeedUrl = '',
  });

  Future<void> _logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final remember = prefs.getBool('remember_login') ?? true;

      await prefs.setBool('is_logged_in', false);
      await prefs.remove('auth_token');

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
        const SnackBar(
          content: Text('Não foi possível encerrar a sessão.'),
        ),
      );
    }
  }

  void _goTab(BuildContext context, int index) {
    Navigator.of(context).pop();
    final shell = RootNavShell.maybeOf(context);
    if (shell != null) {
      shell.setTab(index);
    } else {
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/', (r) => false, arguments: {'tab': index});
    }
  }

  void _goRoute(BuildContext context, String routeName) {
    Navigator.of(context).pop();
    final shell = RootNavShell.maybeOf(context);

    if (shell != null) {
      shell.pushRootNamed(routeName);
    } else {
      Future.microtask(() {
        Navigator.of(context, rootNavigator: true).pushNamed(routeName);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Center(
                child: Text(
                  'Menu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // Banner de notícias logo abaixo do texto "Menu".
            if (noticiasFeedUrl.isNotEmpty)
              NoticiasBannerStrip(
                feedUrl: noticiasFeedUrl,
                height: 140,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              ),

            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
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
  final double verticalPadding;

  const _LogoAction({
    super.key,
    required this.imagePath,
    this.size = 36,
    this.borderRadius = 6,
    this.verticalPadding = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        right: 4,
        top: verticalPadding,
        bottom: verticalPadding,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}