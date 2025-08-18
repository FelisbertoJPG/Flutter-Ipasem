import 'dart:typed_data';

import 'package:flutter/material.dart';

class DigitalCard extends StatelessWidget {
  final String nome, cpf, matricula, plano, validade;
  final Uint8List? photoBytes; //foto futuramente

  const DigitalCard({
    super.key,
    required this.nome,
    required this.cpf,
    required this.matricula,
    required this.plano,
    required this.validade,
    this.photoBytes,
  });

  String _maskCpf(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (d.length != 11) return v;
    return '${d.substring(0,3)}.${d.substring(3,6)}.${d.substring(6,9)}-${d.substring(9)}';
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF143C8D);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0,8))],
        border: Border.all(color: brand, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: brand.withOpacity(0.1),
            foregroundImage: photoBytes != null ? MemoryImage(photoBytes!) : null,
            child: photoBytes == null ? const Icon(Icons.badge_outlined, color: brand) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.black87, height: 1.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('CPF: ${_maskCpf(cpf)}'),
                  Text('Matrícula: $matricula'),
                  Text('Plano: $plano'),
                  Text('Validade: $validade'),
                ],
              ),
            ),
          ),
          const Icon(Icons.qr_code_2, size: 28, color: brand), // placeholder
        ],
      ),
    );
  }
}
