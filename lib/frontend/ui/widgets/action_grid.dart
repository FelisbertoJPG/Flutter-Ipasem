import 'package:flutter/material.dart';
import '../components/action_tile.dart';

class ActionItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  ActionItem({required this.title, required this.icon, required this.onTap, this.iconColor});
}

class ActionGrid extends StatelessWidget {
  const ActionGrid({super.key, required this.items});
  final List<ActionItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 520;
        final itemW = isWide ? (c.maxWidth - 12) / 2 : c.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((it) {
            return ActionTile(
              title: it.title,
              icon: it.icon,
              onTap: it.onTap,
              width: itemW,
              iconColor: it.iconColor,
            );
          }).toList(),
        );
      },
    );
  }
}
