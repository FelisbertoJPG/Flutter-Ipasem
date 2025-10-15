import 'package:flutter/material.dart';

/// Envolve o conteúdo de um SectionCard com:
/// 1) padding externo (respira do card)
/// 2) um "cartão" interno claro com borda sutil
class SectionInset extends StatelessWidget {
  const SectionInset({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double inPad = w < 360 ? 12 : 16;

    return Padding(
      padding: EdgeInsets.all(inPad),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6EDF3), width: 1.5),
        ),
        padding: padding ?? EdgeInsets.all(inPad),
        child: child,
      ),
    );
  }
}
