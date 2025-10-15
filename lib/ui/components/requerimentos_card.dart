// lib/ui/components/requerimentos_card.dart
import 'package:flutter/material.dart';

import '../../core/formatters.dart';          // fmtData
import '../../core/models.dart';              // RequerimentoResumo
import 'section_card.dart';
import 'loading_placeholder.dart';

class RequerimentosEmAndamentoCard extends StatelessWidget {
  const RequerimentosEmAndamentoCard({
    super.key,
    required this.isLoading,
    required this.items,
    this.take = 3,
    this.skeletonHeight = 100,
    this.onTapItem,
  });

  final bool isLoading;
  final List<RequerimentoResumo> items;
  final int take;
  final double skeletonHeight;
  final void Function(RequerimentoResumo item)? onTapItem;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double inPad = w < 360 ? 12 : 16; // padding interno, igual aos outros

    Widget body;
    if (isLoading) {
      body = Column(
        children: [
          LoadingPlaceholder(height: skeletonHeight),
          const SizedBox(height: 8),
          LoadingPlaceholder(height: skeletonHeight * 0.65),
        ],
      );
    } else if (items.isEmpty) {
      body = const _EmptyState();
    } else {
      final data = items.take(take).toList();
      body = Column(
        children: [
          for (int i = 0; i < data.length; i++) ...[
            _ReqTile(
              item: data[i],
              onTap: onTapItem == null ? null : () => onTapItem!(data[i]),
            ),
            if (i != data.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
          ],
        ],
      );
    }

    return SectionCard(
      title: 'Requerimentos em andamento',
      child: Padding(
        padding: EdgeInsets.all(inPad), // respiro do conteúdo do card
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EDF3), width: 1.5),
          ),
          padding: EdgeInsets.all(inPad), // respiro *dentro* da borda interna
          child: body,
        ),
      ),
    );
  }
}

class _ReqTile extends StatelessWidget {
  const _ReqTile({required this.item, this.onTap});

  final RequerimentoResumo item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, size: 24, color: Color(0xFF344054)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Status: ${item.status} • Atualizado: ${fmtData(item.atualizadoEm)}',
                      style: const TextStyle(color: Color(0xFF667085), fontSize: 12.5, height: 1.15),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.assignment_outlined, size: 26, color: Color(0xFF98A2B3)),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nenhum requerimento em andamento',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Quando houverem movimentações, elas aparecerão aqui.',
                style: TextStyle(color: Color(0xFF667085), fontSize: 12.5, height: 1.15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
