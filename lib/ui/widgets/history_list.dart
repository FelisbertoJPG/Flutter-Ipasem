import 'package:flutter/material.dart';
import '../components/loading_placeholder.dart';
import '../components/locked_notice.dart';
import '../../theme/colors.dart';

class HistoryItem {
  final String title;
  final String subtitle; // ex: "10/09/2025 • Autorizada"
  const HistoryItem({required this.title, required this.subtitle});
}

class HistoryList extends StatelessWidget {
  const HistoryList({
    super.key,
    required this.loading,
    required this.isLoggedIn,
    required this.items,
    this.onSeeAll,
    this.emptyLabel = 'Nenhum item no histórico.',
    this.icon = Icons.history,
  });

  final bool loading;
  final bool isLoggedIn;
  final List<HistoryItem> items;
  final VoidCallback? onSeeAll;
  final String emptyLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (loading) return const LoadingPlaceholder(height: 100);
    if (!isLoggedIn) {
      return const LockedNotice(message: 'Faça login para visualizar seu histórico.');
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: const [
            Icon(Icons.history, color: Color(0xFF98A2B3)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nenhum item no histórico.',
                style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...items.map((e) => ListTile(
          dense: true,
          leading: Icon(icon, color: kIconMuted),
          title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(e.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right, color: kBrand),
        )),
        if (onSeeAll != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: onSeeAll,
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('Ver histórico completo'),
            ),
          ),
        ]
      ],
    );
  }
}
