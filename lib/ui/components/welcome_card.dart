import 'package:flutter/material.dart';
import '../../theme/colors.dart'; // kBrand, kCardBg, kCardBorder

class WelcomeCard extends StatelessWidget {
  const WelcomeCard({
    super.key,
    required this.isLoggedIn,
    this.cpf,              // envie já formatado se quiser (ex.: 123.456.789-00)
    required this.onLogin, // usado somente no modo visitante
  });

  final bool isLoggedIn;
  final String? cpf;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título com ícone (sempre exibe o handshake)
          Row(
            children: const [
              Icon(Icons.handshake_outlined, size: 25, color: kBrand),
              SizedBox(width: 8),
              Text(
                'Bem-vindo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Chips de status e (opcional) CPF
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (isLoggedIn)
                const _StatusChip(
                  label: 'Acesso completo',
                  color: Color(0xFF027A48),
                  bg: Color(0xFFD1FADF),
                )
              else
                const _StatusChip(
                  label: 'Acesso limitado',
                  color: Color(0xFF6941C6),
                  bg: Color(0xFFF4EBFF),
                ),
              if (cpf != null && cpf!.isNotEmpty)
                const _StatusChip(
                  label: '',
                  color: Color(0xFF475467),
                  bg: Color(0xFFEFF6F9),
                ).withText('CPF: $cpf'),
            ],
          ),

          const SizedBox(height: 12),

          // CTA só para visitante
          if (!isLoggedIn)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kBrand,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: onLogin,
                icon: const Icon(Icons.login),
                label: const Text('Fazer login'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.bg,
  });

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
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  _StatusChip withText(String text) => _StatusChip(label: text, color: color, bg: bg);
}
