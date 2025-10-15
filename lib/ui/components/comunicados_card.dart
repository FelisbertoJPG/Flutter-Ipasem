import 'package:flutter/material.dart';

import '../../core/formatters.dart';        // fmtData
import '../../core/models.dart';            // ComunicadoResumo
import 'section_list.dart';

class ComunicadosCard extends StatelessWidget {
  const ComunicadosCard({
    super.key,
    required this.isLoading,
    required this.items,
    this.take = 3,
    this.skeletonHeight = 100,
    this.onTapItem,
  });

  final bool isLoading;
  final List<ComunicadoResumo> items;
  final int take;
  final double skeletonHeight;
  final void Function(ComunicadoResumo item)? onTapItem;

  @override
  Widget build(BuildContext context) {
    return SectionList<ComunicadoResumo>(
      title: 'Comunicados',
      isLoading: isLoading,
      items: items,
      take: take,
      skeletonHeight: skeletonHeight,
      itemBuilder: (c) => ListTile(
        dense: true,
        leading: const Icon(Icons.campaign_outlined),
        title: Text(
          c.titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${fmtData(c.data)} • ${c.descricao}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTapItem == null ? null : () => onTapItem!(c),
      ),
      emptyIcon: Icons.campaign_outlined,
      emptyTitle: 'Sem comunicados Publicados',
      emptySubtitle: 'Novos avisos oficiais aparecerão aqui.',
    );
  }
}
