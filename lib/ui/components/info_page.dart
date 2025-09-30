// lib/ui/components/info_page.dart
import 'package:flutter/material.dart';
import '../../ui/app_shell.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({
    super.key,
    required this.title,
    required this.body,
    this.minimal = false, // <— NOVO
  });

  final String title;
  final String body;
  final bool minimal; // <— NOVO

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      minimal: minimal, // <— passa para o AppScaffold
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (minimal) // título interno quando não há AppBar
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            SelectableText(
              body,
              style: const TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
