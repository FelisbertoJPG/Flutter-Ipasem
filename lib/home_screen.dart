// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart'; // necessário para o logout

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  int _counter = 0;
  final _noteCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: const [
          _LogoAction(
            imagePath: 'assets/images/logo_ipasem.png', // ajuste o caminho
            size: 28,
            borderRadius: 6,
          ),
          SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
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
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Sobre'),
              ),
              const ListTile(
                leading: Icon(Icons.privacy_tip_outlined),
                title: Text('Privacidade'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sair'),
                onTap: () async {
                  Navigator.of(context).pop(); // fecha o drawer
                  await _logout(context);
                },
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card 1
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: const Color(0xFFEFF6F9),
            child: const ListTile(
              leading: Icon(Icons.handshake_outlined),
              title: Text(
                'Bem-vindo!',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('Esta é uma tela modelo para testes.'),
            ),
          ),
          const SizedBox(height: 12),

          // Card 2 – text field (persistência entre abas)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Anotações (persiste ao trocar de aba)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Card 3 – contador
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.countertops_outlined),
              title: const Text(
                'Contador',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('Valor atual: $_counter'),
              trailing: FilledButton.icon(
                onPressed: () => setState(() => _counter++),
                icon: const Icon(Icons.add),
                label: const Text('Somar'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // Limpeza opcional de sessão/credenciais
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_cpf');
      await prefs.remove('auth_token');
      await prefs.setBool('is_logged_in', false);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível encerrar a sessão.')),
      );
    }
  }
}

/// Ação de AppBar que garante que qualquer imagem seja contida no quadrado,
/// recortada sem deformar (BoxFit.cover + ClipRRect).
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
            fit: BoxFit.cover,            // “suprime” sobras cortando excesso
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
