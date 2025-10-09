//C:\Users\suporteti2\StudioProjects\ipa_app_flutter\lib\ui\widgets\history_list.dart
import 'package:flutter/material.dart';

class HistoryItem {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const HistoryItem({required this.title, required this.subtitle, this.onTap});
}

class HistoryList extends StatelessWidget {
  final bool loading;
  final bool isLoggedIn;
  final List<HistoryItem> items;
  final VoidCallback? onSeeAll;

  const HistoryList({
    super.key,
    required this.loading,
    required this.isLoggedIn,
    required this.items,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!isLoggedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Text('Faça login para ver seu histórico.'),
          const SizedBox(height: 8),
          if (onSeeAll != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onSeeAll, child: const Text('Ver tudo')),
            ),
        ],
      );
    }

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Sem autorizações recentes.'),
      );
    }

    return Column(
      children: [
        ...items.map((it) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          title: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(it.subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: it.onTap,
        )),
        if (onSeeAll != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onSeeAll, child: const Text('Ver tudo')),
          ),
      ],
    );
  }
}
