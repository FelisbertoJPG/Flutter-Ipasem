// lib/ui/dialogs/digital_card_modal.dart
import 'package:flutter/material.dart';
import '../widgets/digital_card_view.dart';

class DigitalCardData {
  final String nome;
  final String cpf;
  final String matricula;
  final String sexoTxt;
  final String? nascimento;
  final String token;
  final int? expiresAtEpoch;

  const DigitalCardData({
    required this.nome,
    required this.cpf,
    required this.matricula,
    required this.sexoTxt,
    required this.token,
    this.nascimento,
    this.expiresAtEpoch,
  });
}

/// Abre o DigitalCardView como modal bloqueante sobre a Home.
/// - Não fecha por back ou toque fora.
/// - Usa forceLandscape para manter o card “deitado” em telas portrait.
/// - Retorna apenas quando o usuário toca em "Sair".
Future<void> showDigitalCardModal(
    BuildContext context, {
      required DigitalCardData data,
    }) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Carteirinha Digital',
    barrierColor: Colors.black54,
    useRootNavigator: true,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, secAnim) {
      return WillPopScope(
        onWillPop: () async => false, // bloqueia botão "voltar"
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Material(
                type: MaterialType.transparency,
                child: DigitalCardView(
                  nome: data.nome,
                  cpf: data.cpf,
                  matricula: data.matricula,
                  sexoTxt: data.sexoTxt,
                  nascimento: data.nascimento,
                  token: data.token,
                  expiresAtEpoch: data.expiresAtEpoch,
                  // força modo horizontal “tombado” em portrait
                  forceLandscape: true,
                  forceLandscapeOnWide: false,
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, sec, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
