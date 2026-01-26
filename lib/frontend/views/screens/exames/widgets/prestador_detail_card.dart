import 'package:flutter/material.dart';

import '../../../../../common/models/prestador.dart';

class PrestadorDetailCard extends StatelessWidget {
  const PrestadorDetailCard({super.key, required this.prestador});

  final PrestadorRow? prestador;

  @override
  Widget build(BuildContext context) {
    final p = prestador;
    if (p == null) return const SizedBox.shrink();

    String up(String? s) => (s ?? '').trim().toUpperCase();
    final vinc = up((p.vinculoNome != null && p.vinculoNome!.trim().isNotEmpty)
        ? p.vinculoNome
        : p.vinculo);
    final l1 = up(p.endereco);
    final cidadeUf =
    [up(p.cidade), up(p.uf)].where((e) => e.isNotEmpty).join('/');
    final l2 = [up(p.bairro), cidadeUf].where((e) => e.isNotEmpty).join(' - ');

    return Column(
      children: [
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE6E9EF)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Text(up(p.nome),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                if (vinc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(vinc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                ],
                if (l1.isNotEmpty || l2.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (l1.isNotEmpty) Text(l1, textAlign: TextAlign.center),
                  if (l2.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(l2, textAlign: TextAlign.center),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
