// lib/ui/components/comunicados_panel.dart

import 'package:flutter/material.dart';
import '../../core/models.dart'; // ComunicadoResumo

class ComunicadosPanel extends StatelessWidget {
  const ComunicadosPanel({
    super.key,
    required this.items,
    this.isLoading = false,
    this.error,
    this.title = 'Comunicados',
  });

  final List<ComunicadoResumo> items;
  final bool isLoading;
  final String? error;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(title),
        const SizedBox(height: 8),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red))
        else if (items.isEmpty)
            const Text('Sem comunicados publicados')
          else
            Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _ComunicadoItem(item: items[i]),
                  if (i != items.length - 1)
                    const Divider(height: 12, thickness: 1, color: Color(0xFFE5E7EB)),
                ]
              ],
            ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF344054),
      ),
    );
  }
}

class _ComunicadoItem extends StatelessWidget {
  const _ComunicadoItem({required this.item});
  final ComunicadoResumo item;

  String _fmtBR(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    // Fallback caso a data venha nula do backend
    final when = item.data ?? DateTime.now();
    final dataTxt = _fmtBR(when);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        item.titulo,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF101828),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.descricao?.isNotEmpty == true)
            Text(
              item.descricao!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF475467)),
            ),
          const SizedBox(height: 4),
          Text(
            'Publicado em: $dataTxt',
            style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
