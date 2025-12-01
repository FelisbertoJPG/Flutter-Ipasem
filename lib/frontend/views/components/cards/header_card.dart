// lib/ui/components/header_card.dart
import 'package:flutter/material.dart';

import '../../../theme/colors.dart';      // kBrand, kCardBg, kCardBorder
import '../status_chip.dart';            // StatusChip

class HeaderCard extends StatelessWidget {
  const HeaderCard({
    super.key,
    required this.isLoggedIn,
    this.cpf,
    required this.onLogin,
    required this.onPerfil,
  });

  final bool isLoggedIn;
  final String? cpf;                  // já formatado ou bruto (aqui só exibe)
  final VoidCallback onLogin;
  final VoidCallback onPerfil;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: kBrand,
            child: Icon(Icons.person_outline, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn ? 'Sessão ativa' : 'Visitante',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (isLoggedIn)
                      const StatusChip(
                        label: 'Acesso completo',
                        color: Color(0xFF027A48),
                        bg: Color(0xFFD1FADF),
                      )
                    else
                      const StatusChip(
                        label: 'Acesso limitado',
                        color: Color(0xFF6941C6),
                        bg: Color(0xFFF4EBFF),
                      ),
                    if (cpf != null && cpf!.isNotEmpty)
                      const StatusChip(
                        // Dica: se quiser exibir o CPF, passe formatado na Home e troque o label aqui.
                        label: 'CPF informado',
                        color: Color(0xFF475467),
                        bg: Color(0xFFEFF6F9),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!isLoggedIn)
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: kBrand,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: onLogin,
                          icon: const Icon(Icons.login),
                          label: const Text('Fazer login'),
                        ),
                      )
                    else
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPerfil,
                          icon: const Icon(Icons.person),
                          label: const Text('Ver perfil'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
