// lib/profile_screen.dart
import 'package:flutter/material.dart';

/// Cores alinhadas com as outras telas
const _brand       = Color(0xFF143C8D);
const _cardBg      = Color(0xFFEFF6F9);
const _cardBorder  = Color(0xFFE2ECF2);
const _panelBg     = Color(0xFFF4F5F7);
const _panelBorder = Color(0xFFE5E8EE);

class ProfileScreen extends StatefulWidget {
  /// Para este passo, mantemos visitante como padrão.
  final bool isVisitor;

  /// Callback para acionar sua tela de login (Navigator.push ...)
  final VoidCallback? onRequestSignIn;

  /// Callback para "Criar conta" (opcional)
  final VoidCallback? onRequestSignUp;

  const ProfileScreen({
    super.key,
    this.isVisitor = true,
    this.onRequestSignIn,
    this.onRequestSignUp,
  });

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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: const [
          // reservado para futuras ações (ex.: notificações)
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== Cabeçalho =====
          _HeaderCardVisitor(
            onLogin: widget.onRequestSignIn ??
                    () => _fallbackSnack('Ação de login não configurada.'),
            onSignUp: widget.onRequestSignUp ??
                    () => _fallbackSnack('Ação de criação de conta não configurada.'),
          ),

          const SizedBox(height: 16),

          // ===== Dados bloqueados (somente após login) =====
          _SectionCard(
            title: 'Dados do usuário',
            child: Column(
              children: const [
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

          _SectionCard(
            title: 'Benefícios',
            child: Column(
              children: const [
                _LockedInfoRow(label: 'Plano de saúde'),
                _LockedInfoRow(label: 'Dependentes'),
                _LockedInfoRow(label: 'Autorizações recentes'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ===== Atalhos informativos / legais =====
          _SectionCard(
            title: 'Informações',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Sobre o aplicativo'),
                  subtitle: const Text('Versão, mantenedor e informações gerais.'),
                  onTap: () => _fallbackSnack('Sobre: implementar navegação.'),
                  minLeadingWidth: 0,
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Política de Privacidade'),
                  onTap: () => _fallbackSnack('Privacidade: implementar navegação.'),
                  minLeadingWidth: 0,
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Termos de Uso'),
                  onTap: () => _fallbackSnack('Termos: implementar navegação.'),
                  minLeadingWidth: 0,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Dica final
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _panelBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _panelBorder),
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

// ================== Widgets de composição ==================

class _HeaderCardVisitor extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  const _HeaderCardVisitor({
    required this.onLogin,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _blockDecoration(),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: _brand,
            child: const Icon(Icons.person_outline, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),

          // Títulos + chips (com quebra automática)
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

                // ALTERAÇÃO: Row -> Wrap para evitar overflow horizontal
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
    ).wrapWithActions(
      primary: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _brand,
          minimumSize: const Size.fromHeight(44),
        ),
        onPressed: onLogin,
        icon: const Icon(Icons.login),
        label: const Text('Fazer login'),
      ),
      secondary: OutlinedButton.icon(
        onPressed: onSignUp,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Criar conta'),
      ),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _blockDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF475467),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
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
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF101828),
        ),
      ),
      subtitle: const Text(
        'Disponível após login',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Color(0xFF667085)),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
      onTap: null, // bloqueado no modo visitante
      minLeadingWidth: 0,
    );
  }
}

// ================== Helpers de UI ==================

BoxDecoration _blockDecoration() => BoxDecoration(
  color: _cardBg,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: _cardBorder, width: 2),
);

extension _ActionArea on Widget {
  /// Anexa uma área de ações (botões) abaixo do bloco, com espaçamento consistente.
  Widget wrapWithActions({required Widget primary, Widget? secondary}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        this,
        const SizedBox(height: 12),
        primary,
        if (secondary != null) ...[
          const SizedBox(height: 8),
          secondary,
        ],
      ],
    );
  }
}
