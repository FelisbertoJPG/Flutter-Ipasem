// lib/root_nav_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/home_screen.dart';
import 'screens/home_servicos.dart';   // HomeServicos
import 'screens/profile_screen.dart';  // ProfileScreen (Visitante)

class RootNavShell extends StatefulWidget {
  const RootNavShell({super.key});

  @override
  State<RootNavShell> createState() => _RootNavShellState();
}

class _RootNavShellState extends State<RootNavShell> {
  final PageController _pageController = PageController(initialPage: 0);

  // Índice usado pelo PageView/NavigationBar
  int _currentIndex = 0;

  // Contatos
  static const String _tel = 'tel:5135949162';
  static const String _email = 'contato@ipasemnh.com.br';
  static const String _emailSubject = 'Atendimento IPASEM';
  static const String _emailBody = 'Olá, preciso de ajuda no app.';

  // Páginas
  late final List<Widget> _pages = const [
    _KeepAlive(child: HomeScreen()),
    _KeepAlive(child: HomeServicos()),
    _KeepAlive(child: ProfileScreen()),
  ];

  // Índices
  static const int _tabHome = 0;
  static const int _tabServicos = 1;
  static const int _tabPerfil = 2;
  static const int _tabContatos = 3; // abre sheet (não navega)

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goTo(int index) async {
    if (index == _tabContatos) {
      await _showContactsSheet(context);
      return;
    }
    if (_currentIndex == index) return;

    setState(() => _currentIndex = index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Barra inferior compacta
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
        onDestinationSelected: _goTo,
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

    return Scaffold(
      // Sem AppBar
      body: PageView(
        controller: _pageController,
        // Remova para permitir swipe entre páginas
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) {
          // Mantém a NavigationBar sincronizada (também cobre swipe se habilitar)
          setState(() => _currentIndex = i);
        },
        children: _pages,
      ),
      bottomNavigationBar: bottomBar,
    );
  }

  // ===== Bottom sheet de contatos =====
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
                // drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE5EE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Contatos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
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

  // ===== Helpers =====
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
      'view': 'cm',
      'fs': '1',
      'to': _email,
      'su': _emailSubject,
      'body': _emailBody,
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

/// Mantém cada aba viva
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child, super.key});
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
