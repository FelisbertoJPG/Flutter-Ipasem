import 'package:flutter/material.dart';

import '../../core/formatters.dart';              // fmtData
import '../../core/models.dart';                  // RequerimentoResumo
import 'section_list.dart';                       // seu wrapper de lista

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
    return SectionList<RequerimentoResumo>(
      title: 'Requerimentos em andamento',
      isLoading: isLoading,
      items: items,
      take: take,
      skeletonHeight: skeletonHeight,
      itemBuilder: (e) => ListTile(
        dense: true,
        leading: const Icon(Icons.description_outlined),
        title: Text(
          e.titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Status: ${e.status} • Atualizado: ${fmtData(e.atualizadoEm)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTapItem == null ? null : () => onTapItem!(e),
      ),
      emptyIcon: Icons.assignment_outlined,
      emptyTitle: 'Nenhum requerimento em andamento',
      emptySubtitle:
      'Quando houverem movimentações, elas aparecerão aqui.',
    );
  }
}
