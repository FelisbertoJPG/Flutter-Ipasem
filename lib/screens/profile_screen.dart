// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/colors.dart';                    // kBrand, kCardBg, kCardBorder, kPanelBg, kPanelBorder
import '../ui/app_shell.dart';                    // AppScaffold (AppBar + Drawer padrão)
import '../ui/components/section_card.dart';      // SectionCard reutilizável
import '../screens/login_screen.dart';            // fallback no push se rota não existir

// URL "Criar conta" (prestador) — atualizada
const _createAccountUrl =
    'https://assistweb.ipasemnh.com.br/requerimentos/recuperar-senha-prestador';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _fallbackSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- Navegação segura para Login (rootNavigator + fallback) ---
  void _goToLogin() {
    FocusScope.of(context).unfocus();
    try {
      Navigator.of(context, rootNavigator: true).pushNamed('/login');
    } catch (_) {
      // fallback se a rota nomeada não estiver registrada
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_cpf');
      await prefs.remove('auth_token');
      await prefs.setBool('is_logged_in', false);
      if (!mounted) return;

      // prefira rootNavigator para sair da shell/tab atual
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/login', (route) => false);

      // Fallback (se a rota não existir):
      // Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      //   MaterialPageRoute(builder: (_) => const LoginScreen()),
      //   (route) => false,
      // );
    } catch (_) {
      if (!mounted) return;
      _fallbackSnack('Não foi possível encerrar a sessão.');
    }
  }

  Future<void> _openCreateAccount() async {
    try {
      final ok = await launchUrl(
        Uri.parse(_createAccountUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception();
    } catch (_) {
      if (!mounted) return;
      _fallbackSnack('Não foi possível abrir o link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AppScaffold(
      title: 'Perfil',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== Cabeçalho (Visitante) =====
          _HeaderCardVisitor(
            onLogin: _goToLogin,                // usa rootNavigator + fallback
            onSignUp: _openCreateAccount,       // abre URL externa
          ),

          const SizedBox(height: 16),

          // ===== Dados bloqueados (somente após login) =====
          const SectionCard(
            title: 'Dados do usuário',
            child: Column(
              children: [
                _LockedInfoRow(label: 'Nome completo'),
                _LockedInfoRow(label: 'CPF'),
                _LockedInfoRow(label: 'Matrícula'),
                _LockedInfoRow(label: 'E-mail'),
                _LockedInfoRow(label: 'Telefone'),
                _LockedInfoRow(label: 'Data de nascimento'),
                _LockedInfoRow(label: 'Vínculo / Situação'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          const SectionCard(
            title: 'Benefícios',
            child: Column(
              children: [
                _LockedInfoRow(label: 'Plano de saúde'),
                _LockedInfoRow(label: 'Dependentes'),
                _LockedInfoRow(label: 'Autorizações recentes'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ===== Atalhos informativos / legais =====
          SectionCard(
            title: 'Informações',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Sobre o aplicativo'),
                  subtitle: const Text('Versão, mantenedor e informações gerais.'),
                  onTap: () => Navigator.of(context, rootNavigator: true).pushNamed('/sobre'),
                  minLeadingWidth: 0,
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Política de Privacidade'),
                  onTap: () => Navigator.of(context, rootNavigator: true).pushNamed('/privacidade'),
                  minLeadingWidth: 0,
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Termos de Uso'),
                  onTap: () => _fallbackSnack('Termos: implementar rota /termos'),
                  minLeadingWidth: 0,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sair'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kBrand, width: 1.4),
                      foregroundColor: kBrand,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Dica final
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPanelBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPanelBorder),
            ),
            child: const Text(
              'Você está logado como Visitante. Faça login para visualizar seus dados '
                  'pessoais e informações de benefícios.',
              style: TextStyle(color: Color(0xFF475467)),
            ),
          ),
        ],
      ),
    );
  }
}

// ================== Widgets específicos ==================

class _HeaderCardVisitor extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  const _HeaderCardVisitor({
    required this.onLogin,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Card principal
        Container(
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kCardBorder, width: 2),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: kBrand,
                child: Icon(Icons.person_outline, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visitante',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: const [
                        _StatusChip(
                          label: 'Logado como Visitante',
                          color: Color(0xFFB54708), // âmbar
                          bg: Color(0xFFFFF4E5),
                        ),
                        _StatusChip(
                          label: 'Acesso limitado',
                          color: Color(0xFF6941C6),
                          bg: Color(0xFFF4EBFF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Ações
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kBrand),
            onPressed: onLogin,
            icon: const Icon(Icons.login),
            label: const Text('Fazer login'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: onSignUp,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Criar conta'),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _StatusChip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bg),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LockedInfoRow extends StatelessWidget {
  final String label;

  const _LockedInfoRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.lock_outline, color: Color(0xFF667085)),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF101828)),
      ),
      subtitle: const Text(
        'Disponível após login',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Color(0xFF667085)),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
      minLeadingWidth: 0,
    );
  }
}
