// lib/ui/components/info_page.dart
import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../app_shell.dart'; // se usa AppScaffold

class InfoPage extends StatelessWidget {
  const InfoPage({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCardBorder, width: 2),
            ),
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              body,
              style: const TextStyle(height: 1.35, color: Color(0xFF344054)),
            ),
          ),
        ],
      ),
    );
  }
}
