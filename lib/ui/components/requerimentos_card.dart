import 'package:flutter/material.dart';

import '../../core/formatters.dart';          // fmtData
import '../../core/models.dart';              // RequerimentoResumo
import '../../models/exame.dart';             // ExameResumo
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
    this.extraInner, // << NOVO
  });

  final bool isLoading;
  final List<RequerimentoResumo> items;
  final int take;
  final double skeletonHeight;
  final void Function(RequerimentoResumo item)? onTapItem;

  /// Qualquer conteúdo adicional para aparecer DENTRO da moldura interna
  /// (perfeito para a lista inline de exames).
  final Widget? extraInner; // << NOVO

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery
        .of(context)
        .size
        .width;
    final double inPad = w < 360 ? 12 : 16;

    // Decide o que mostrar na parte "requerimentos"
    Widget? reqPart;
    if (isLoading) {
      reqPart = Column(
        children: [
          LoadingPlaceholder(height: skeletonHeight),
          const SizedBox(height: 8),
          LoadingPlaceholder(height: skeletonHeight * 0.65),
        ],
      );
    } else if (items.isNotEmpty) {
      final data = items.take(take).toList();
      reqPart = Column(
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
    } else {
      // Só mostra o vazio se NÃO existir extraInner.
      if (extraInner == null) {
        reqPart = const _EmptyState();
      } else {
        reqPart = null; // suprime o vazio quando há a seção de exames
      }
    }

    final children = <Widget>[
      if (reqPart != null) reqPart,
      if (extraInner != null) ...[
        if (reqPart != null) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
        ],
        extraInner!,
      ],
    ];

    return SectionCard(
      title: 'Requerimentos em andamento',
      child: Padding(
        padding: EdgeInsets.all(inPad),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EDF3), width: 1.5),
          ),
          padding: EdgeInsets.all(inPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}


  class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF344054)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, size: 22, color: Color(0xFF344054)),
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

class _ExamTile extends StatelessWidget {
  const _ExamTile({required this.exame, this.onTap});
  final ExameResumo exame;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final st = (exame.status ?? '').toUpperCase();
    final isLiberado = st == 'A';
    final chipColor = isLiberado ? const Color(0xFF12B76A) : const Color(0xFFF79009);
    final chipBg    = isLiberado ? const Color(0xFFEFFDF5) : const Color(0xFFFFF7E8);
    final chipText  = isLiberado ? 'Liberado' : 'Pendente';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exame #${exame.numero} — ${exame.paciente}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${exame.prestador}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF667085), fontSize: 12.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Emitido: ${exame.dataHora.isEmpty ? '—' : exame.dataHora}',
                      style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chipText,
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
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
