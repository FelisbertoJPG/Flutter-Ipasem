import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import 'action_tile.dart'; // ActionTile

class QuickActions extends StatelessWidget {
  final VoidCallback onCarteirinha;
  final VoidCallback onAssistenciaSaude;
  final VoidCallback onAutorizacoes;

  const QuickActions({
    super.key,
    required this.onCarteirinha,
    required this.onAssistenciaSaude,
    required this.onAutorizacoes,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 520;
        return Container(
          decoration: BoxDecoration(
            color: kPanelBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kPanelBorder, width: 2),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ações rápidas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475467),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ActionTile(
                    title: 'Carteirinha Digital',
                    icon: Icons.badge_outlined,
                    onTap: onCarteirinha,
                    width: isWide ? (c.maxWidth - 12) / 2 : c.maxWidth,
                  ),
                  ActionTile(
                    title: 'Assistência à Saúde',
                    icon: Icons.local_hospital_outlined,
                    onTap: onAssistenciaSaude,
                    width: isWide ? (c.maxWidth - 12) / 2 : c.maxWidth,
                  ),
                  ActionTile(
                    title: 'Autorizações',
                    icon: Icons.medical_information_outlined,
                    onTap: onAutorizacoes,
                    width: isWide ? (c.maxWidth - 12) / 2 : c.maxWidth,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
