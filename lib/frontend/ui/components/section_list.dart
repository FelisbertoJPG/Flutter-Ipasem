import 'package:flutter/material.dart';

import 'section_card.dart';
import 'loading_placeholder.dart';
import 'empty_state.dart';

typedef ItemBuilder<T> = Widget Function(T item);

class SectionList<T> extends StatelessWidget {
  const SectionList({
    super.key,
    required this.title,
    required this.isLoading,
    required this.items,
    required this.itemBuilder,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Sem itens',
    this.emptySubtitle,
    this.skeletonHeight = 100,
    this.take = 3,
  });

  final String title;
  final bool isLoading;
  final List<T> items;
  final ItemBuilder<T> itemBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;
  final double skeletonHeight;
  final int take;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: isLoading
          ? LoadingPlaceholder(height: skeletonHeight)
          : (items.isEmpty
          ? EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      )
          : Column(
        children: items.take(take).map(itemBuilder).toList(),
      )),
    );
  }
}
