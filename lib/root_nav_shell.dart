import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ipasemnhdigital/screens/autorizacao_exames_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/home_screen.dart';
import 'screens/home_servicos.dart';
import 'screens/profile_screen.dart';
import 'screens/autorizacao_medica_screen.dart';
import 'screens/autorizacao_odontologica_screen.dart'; // <- NOVO

class RootNavShell extends StatefulWidget {
  const RootNavShell({super.key});

  static RootNavScope? maybeOf(BuildContext context) =>
      RootNavScope.maybeOf(context);

  @override
  State<RootNavShell> createState() => _RootNavShellState();
}

class _RootNavShellState extends State<RootNavShell> {
  final _tabKeys = <int, GlobalKey<NavigatorState>>{
    0: GlobalKey<NavigatorState>(), // Início
    1: GlobalKey<NavigatorState>(), // Serviços
    2: GlobalKey<NavigatorState>(), // Perfil
  };

  int _currentIndex = 0;
  bool _handledArgs = false;

  // Swipe entre abas
  late final PageController _pageController =
  PageController(initialPage: _currentIndex);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledArgs) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['tab'] is int) {
      final idx = args['tab'] as int;
      if (idx >= 0 && idx <= 2) {
        _currentIndex = idx;
        _pageController.jumpToPage(_currentIndex);
      }
    }
    _handledArgs = true;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const String _tel = 'tel:5135949162';
  static const String _email = 'contato@ipasemnh.com.br';
  static const String _emailSubject = 'Atendimento IPASEM';
  static const String _emailBody = 'Olá, preciso de ajuda no app.';

  void _setTab(int i) {
    if (_currentIndex == i) {
      _tabKeys[i]?.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _currentIndex = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<T?> _pushInServicos<T>(
      String name, {
        Object? arguments,
        bool switchTab = true,
      }) {
    if (switchTab && _currentIndex != 1) {
      setState(() => _currentIndex = 1);
      _pageController.jumpToPage(1);
    }
    final nav = _tabKeys[1]!.currentState!;
    return nav.pushNamed<T>(name, arguments: arguments);
  }

  /// BACK centralizado (físico/sistema):
  /// 1) Se a aba atual tem rotas para voltar, faz pop nela.
  /// 2) Caso contrário, muda para Serviços (aba 1). Se já estiver em Serviços,
  ///    muda para Início (aba 0). Nunca fecha o app.
  Future<bool> _handleSystemBack() async {
    final currentNav = _tabKeys[_currentIndex]!.currentState!;
    if (currentNav.canPop()) {
      currentNav.pop();
      return false; // impede o pop global
    }

    // Fallbacks de navegação entre abas
    if (_currentIndex != 1) {
      _setTab(1); // prioriza Serviços
      return false;
    }
    if (_currentIndex != 0) {
      _setTab(0); // depois Início
      return false;
    }

    // Já está no root de Início. Não fecha o app.
    return false;
  }

  // Exposto via InheritedWidget para uso opcional (ex.: no leading de AppBars)
  Future<void> _safeBack() async {
    await _handleSystemBack();
  }

  Route<dynamic> _routeHome(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => const HomeScreen(),
      settings: const RouteSettings(name: 'home-root'),
    );
  }

  Route<dynamic> _routeServicos(RouteSettings settings) {
    switch (settings.name) {
      case '/':
      case 'servicos-root':
        return MaterialPageRoute(
          builder: (_) => const HomeServicos(),
          settings: const RouteSettings(name: 'servicos-root'),
        );
      case 'autorizacao-medica':
        return MaterialPageRoute(
          builder: (_) => const AutorizacaoMedicaScreen(),
          settings: const RouteSettings(name: 'autorizacao-medica'),
        );
      case 'autorizacao-odontologica': // <- NOVO
        return MaterialPageRoute(
          builder: (_) => const AutorizacaoOdontologicaScreen(),
          settings: const RouteSettings(name: 'autorizacao-odontologica'),
        );
      case 'autorizacao-exames': // <- NOVO
        return MaterialPageRoute(
          builder: (_) => const AutorizacaoExamesScreen(),
          settings: const RouteSettings(name: 'autorizacao-exames'),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const HomeServicos(),
          settings: const RouteSettings(name: 'servicos-root'),
        );
    }
  }

  Route<dynamic> _routePerfil(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => const ProfileScreen(),
      settings: const RouteSettings(name: 'perfil-root'),
    );
  }

  Widget _tabNavigator({
    required int index,
    required RouteFactory onGenerateRoute,
  }) {
    return Navigator(
      key: _tabKeys[index],
      onGenerateRoute: onGenerateRoute,
    );
  }

  @override
  Widget build(BuildContext context) {
    const double _iconSize = 22;
    final iconTheme = const IconThemeData(size: _iconSize);

    final bottomBar = DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE6E9EF), width: 1)),
      ),
      child: NavigationBar(
        height: 56,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          if (i == 3) {
            _showContactsSheet(context);
            return;
          }
          _setTab(i);
        },
        destinations: [
          NavigationDestination(
            tooltip: 'Início',
            icon: IconTheme(data: iconTheme, child: const Icon(Icons.home_outlined)),
            selectedIcon: IconTheme(data: iconTheme, child: const Icon(Icons.home)),
            label: 'Início',
          ),
          NavigationDestination(
            tooltip: 'Serviços',
            icon: IconTheme(data: iconTheme, child: const Icon(Icons.grid_view_outlined)),
            selectedIcon: IconTheme(data: iconTheme, child: const Icon(Icons.grid_view)),
            label: 'Serviços',
          ),
          NavigationDestination(
            tooltip: 'Perfil',
            icon: IconTheme(data: iconTheme, child: const Icon(Icons.person_outline)),
            selectedIcon: IconTheme(data: iconTheme, child: const Icon(Icons.person)),
            label: 'Perfil',
          ),
          NavigationDestination(
            tooltip: 'Contatos',
            icon: IconTheme(data: iconTheme, child: const Icon(Icons.headset_mic_outlined)),
            selectedIcon: IconTheme(data: iconTheme, child: const Icon(Icons.headset_mic)),
            label: 'Contatos',
          ),
        ],
      ),
    );

    return WillPopScope( // <- back centralizado
      onWillPop: _handleSystemBack,
      child: RootNavScope(
        setTab: _setTab,
        currentIndex: _currentIndex,
        pushInServicos: _pushInServicos,
        safeBack: _safeBack, // expõe para quem quiser usar
        child: Scaffold(
          body: PageView(
            controller: _pageController,
            physics: const PageScrollPhysics(),
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
            },
            children: [
              _tabNavigator(index: 0, onGenerateRoute: _routeHome),
              _tabNavigator(index: 1, onGenerateRoute: _routeServicos),
              _tabNavigator(index: 2, onGenerateRoute: _routePerfil),
            ],
          ),
          bottomNavigationBar: bottomBar,
        ),
      ),
    );
  }

  Future<void> _showContactsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE5EE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text('Contatos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.call_outlined),
                  title: const Text('Ligar'),
                  subtitle: const Text('(51) 3594-9162'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _launchTel(_tel, context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.alternate_email_outlined),
                  title: const Text('Enviar E-mail'),
                  subtitle: const Text(_email),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _launchEmail(context);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchTel(String raw, BuildContext context) async {
    final uri = Uri.parse(raw);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('falha ao abrir telefone');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível iniciar a ligação.')),
      );
    }
  }

  Future<void> _launchEmail(BuildContext context) async {
    final mail = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: {'subject': _emailSubject, 'body': _emailBody},
    );
    try {
      final ok = await launchUrl(mail, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    final gmailWeb = Uri.https('mail.google.com', '/mail/', {
      'view': 'cm', 'fs': '1', 'to': _email, 'su': _emailSubject, 'body': _emailBody,
    });
    try {
      final ok = await launchUrl(gmailWeb, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    await Clipboard.setData(const ClipboardData(text: _email));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nenhum app de e-mail encontrado. Endereço copiado.')),
    );
  }
}

class RootNavScope extends InheritedWidget {
  const RootNavScope({
    super.key,
    required this.setTab,
    required this.currentIndex,
    required this.pushInServicos,
    required this.safeBack,
    required super.child,
  });

  final void Function(int index) setTab;
  final int currentIndex;

  final Future<T?> Function<T>(
      String routeName, {
      Object? arguments,
      bool switchTab,
      }) pushInServicos;

  /// Exposto para um “voltar com fallback” consistente (opcional).
  final Future<void> Function() safeBack;

  static RootNavScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RootNavScope>();
  }

  @override
  bool updateShouldNotify(RootNavScope oldWidget) =>
      oldWidget.currentIndex != currentIndex;
}
