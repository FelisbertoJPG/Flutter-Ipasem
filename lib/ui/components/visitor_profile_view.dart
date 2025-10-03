import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import 'section_card.dart';

/// Visão completa para usuário visitante (cabeçalho + blocos bloqueados + dica)
class VisitorProfileView extends StatelessWidget {
  const VisitorProfileView({
    super.key,
    required this.onLogin,
    required this.onSignUp,
  });

  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _VisitorHeader(),           // card com botões
        SizedBox(height: 16),
        _LockedDataBlocks(),        // blocos “Dados do usuário/Benefícios”
        SizedBox(height: 24),
        _VisitorHint(),             // dica final
      ],
    ).withCallbacks(onLogin, onSignUp);
  }
}

/// --------- partes internas (privadas) ---------

class _VisitorHeader extends StatelessWidget {
  const _VisitorHeader({this.onLogin, this.onSignUp});
  final VoidCallback? onLogin;
  final VoidCallback? onSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Visitante',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatusChip(
                          label: 'Logado como Visitante',
                          color: Color(0xFFB54708),
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

class _LockedDataBlocks extends StatelessWidget {
  const _LockedDataBlocks();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SectionCard(
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
        SizedBox(height: 12),
        SectionCard(
          title: 'Benefícios',
          child: Column(
            children: [
              _LockedInfoRow(label: 'Plano de saúde'),
              _LockedInfoRow(label: 'Dependentes'),
              _LockedInfoRow(label: 'Autorizações recentes'),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisitorHint extends StatelessWidget {
  const _VisitorHint();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color, required this.bg});
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bg),
      ),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _LockedInfoRow extends StatelessWidget {
  const _LockedInfoRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.lock_outline, color: Color(0xFF667085)),
      title: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF101828))),
      subtitle: const Text('Disponível após login',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF667085))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
      minLeadingWidth: 0,
    );
  }
}

/// Pequena extensão só para injetar callbacks no header sem expor publicamente.
extension on Column {
  Widget withCallbacks(VoidCallback onLogin, VoidCallback onSignUp) {
    final children = (this.children).toList();
    final headerIndex = children.indexWhere((w) => w is _VisitorHeader);
    if (headerIndex != -1) {
      children[headerIndex] = _VisitorHeader(onLogin: onLogin, onSignUp: onSignUp);
    }
    return Column(children: children);
  }
}
