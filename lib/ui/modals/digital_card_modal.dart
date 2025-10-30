// lib/ui/modals/digital_card_modal.dart
import 'package:flutter/material.dart';
import '../widgets/digital_card_view.dart';

/// Dados necessários para renderizar o cartão
class DigitalCardInput {
  final String nome;
  final String cpf;
  final String matricula;
  final String sexoTxt;
  final String token;
  final String? nascimento;
  final int? expiresAtEpoch;

  const DigitalCardInput({
    required this.nome,
    required this.cpf,
    required this.matricula,
    required this.sexoTxt,
    required this.token,
    this.nascimento,
    this.expiresAtEpoch,
  });
}

/// Mostra o cartão como modal bloqueante, retornando somente ao clicar em “Sair”.
Future<void> showDigitalCardModal(
    BuildContext context, {
      required DigitalCardInput input,
      bool useRootNavigator = true,
    }) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,            // não fecha tocando fora
    barrierLabel: 'DigitalCard',
    barrierColor: Colors.black54,         // escurece o fundo
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, __, ___) {
      final curved =
      CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);

      return WillPopScope(                   // bloqueia botão voltar
        onWillPop: () async => false,
        child: FadeTransition(
          opacity: curved,
          child: Center(
            child: SafeArea(
              minimum: const EdgeInsets.all(12),
              child: Material(                // permite ripple/fonts corretos
                color: Colors.transparent,
                child: DigitalCardView(
                  nome: input.nome,
                  cpf: input.cpf,
                  matricula: input.matricula,
                  sexoTxt: input.sexoTxt,
                  nascimento: input.nascimento,
                  token: input.token,
                  expiresAtEpoch: input.expiresAtEpoch,
                  // Fecha apenas pelo botão "Sair" do card
                  onClose: () => Navigator.of(ctx, rootNavigator: useRootNavigator).pop(),
                  // Mantém comportamento atual: força horizontal apenas em telas largas
                  forceLandscape: false,
                  forceLandscapeOnWide: true,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
