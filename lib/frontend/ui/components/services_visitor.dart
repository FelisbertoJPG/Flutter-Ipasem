import 'package:flutter/material.dart';
import '../components/section_card.dart';
import '../components/locked_notice.dart';

/// Card "Serviços" para VISITANTE, idêntico ao estilo do card bloqueado do histórico.
/// Mostra apenas a mensagem com cadeado. Opcionalmente pode ser clicável para ir ao login.
class ServicesVisitors extends StatelessWidget {
  const ServicesVisitors({
    super.key,
    this.title = 'Serviços',
    this.message = 'Faça login para acessar os serviços.',
    this.onLoginTap,
  });

  final String title;
  final String message;
  final VoidCallback? onLoginTap;

  @override
  Widget build(BuildContext context) {
    final content = LockedNotice(message: message);

    return SectionCard(
      title: title,
      child: onLoginTap == null
          ? content
          : InkWell(
        // clique opcional que pode levar ao login
        borderRadius: BorderRadius.circular(16),
        onTap: onLoginTap,
        child: content,
      ),
    );
  }
}
