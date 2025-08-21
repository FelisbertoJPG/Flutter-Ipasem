// lib/login.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'webview_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color _brandBlue = Color(0xFF143C8D);
  static const Color _accentPurple = Color(0xFF6A37B8);

  // URLs do assistweb
  static const String _loginUrl = 'https://assistweb.ipasemnh.com.br/site/login';
  static const String _primeiroAcessoUrl = 'https://assistweb.ipasemnh.com.br/site/recuperar-senha';

  static const String _prefsKeyCpf = 'saved_cpf';

  final TextEditingController _cpfController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedCpf();
  }

  Future<void> _loadSavedCpf() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKeyCpf) ?? '';
    if (saved.isNotEmpty) {
      _cpfController.text = saved;
      setState(() {});
    }
  }

  Future<void> _saveCpf() async {
    final prefs = await SharedPreferences.getInstance();
    final digits = _cpfController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty) {
      await prefs.setString(_prefsKeyCpf, digits);
    }
  }
  // Envia o CPF pra proxima view
  void _openWeb(String url, String title) async {
    await _saveCpf();
    if (!mounted) return;
    final cpfDigits = _cpfController.text.replaceAll(RegExp(r'\D'), '');
    //permitir voltar ao Login:
    Navigator.of(context).push(
    slideUpRoute(
    WebViewScreen(url: url, title: title, initialCpf: cpfDigits),
    ),
     );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/images/icons/logo_ipasem.png',
                    height: 72,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Insira seu CPF',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                      .copyWith(color: _brandBlue),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _cpfController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    hintText: '000.000.000-00',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _brandBlue, width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _brandBlue, width: 2.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _openWeb(_loginUrl, 'Login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandBlue,
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ENTRAR',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Center(
                  child: TextButton(
                    onPressed: () => _openWeb(_primeiroAcessoUrl, 'Primeiro Acesso'),
                    child: const Text(
                      'Primeiro Acesso? Clique Aqui!!',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    'Duvidas ?',
                    style: const TextStyle(fontWeight: FontWeight.w600)
                        .copyWith(color: _accentPurple),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.alternate_email_outlined,
                        label: 'Enviar E-mail',
                        iconColor: _brandBlue,
                        labelColor: _accentPurple,
                        onTap: () async {
                          final uri = Uri(
                            scheme: 'mailto',
                            path: 'contato@ipasemnh.com.br',
                            query: 'subject=Atendimento%20IPASEM&body=Olá,%20preciso%20de%20ajuda%20no%20app.',
                          );
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.add_call,
                        label: 'Ligar',
                        iconColor: _brandBlue,
                        labelColor: _accentPurple,
                        onTap: () async {
                          final uri = Uri.parse('tel:+5551359491629');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color labelColor;
  final Color iconColor;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.labelColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: labelColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
Route<T> slideUpRoute<T>(Widget page, {int durationMs = 420}) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration(milliseconds: durationMs),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final offset = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved);
      return SlideTransition(position: offset, child: child);
    },
  );
}

