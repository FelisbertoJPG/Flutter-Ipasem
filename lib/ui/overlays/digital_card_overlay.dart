// lib/ui/overlays/digital_card_overlay.dart
import 'package:flutter/material.dart';
import '../widgets/digital_card_view.dart';

class DigitalCardOverlayArgs {
  final String nome;
  final String cpf;
  final String matricula;
  final String sexoTxt;
  final String? nascimento;
  final String token;
  final int? expiresAtEpoch;

  const DigitalCardOverlayArgs({
    required this.nome,
    required this.cpf,
    required this.matricula,
    required this.sexoTxt,
    required this.token,
    this.nascimento,
    this.expiresAtEpoch,
  });
}

/// Abre a Carteirinha como um MODAL por cima da app (bloqueando tudo)
/// até o usuário tocar em "Sair". Não permite fechar por fora nem pelo back.
Future<void> showDigitalCardOverlay(
    BuildContext context, {
      required DigitalCardOverlayArgs data,
    }) {
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,              // sobe até o root
    barrierDismissible: false,           // não fecha tocando fora
    barrierLabel: 'Carteirinha Digital',
    barrierColor: Colors.black54,        // escurece o fundo
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, a1, a2) {
      return WillPopScope(               // bloqueia botão "voltar"
        onWillPop: () async => false,
        child: SafeArea(
          child: Material(
            type: MaterialType.transparency,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DigitalCardView(
                  nome: data.nome,
                  cpf: data.cpf,
                  matricula: data.matricula,
                  sexoTxt: data.sexoTxt,
                  nascimento: data.nascimento,
                  token: data.token,
                  expiresAtEpoch: data.expiresAtEpoch,
                  // Única forma de fechar
                  onClose: () => Navigator.of(ctx, rootNavigator: true).pop(),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
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
