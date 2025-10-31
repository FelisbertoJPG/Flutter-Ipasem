// lib/ui/sheets/card_sheet.dart
import 'package:flutter/material.dart';

import '../../models/card_token_models.dart';
import '../../services/carteirinha_service.dart';
import '../widgets/digital_card_view.dart';

/// Abre a Carteirinha em overlay full-screen (não usa bottom-sheet),
/// mantendo a mesma assinatura pública.
Future<void> showDigitalCardSheet(
    BuildContext context, {
      required CardTokenData data,
      required CarteirinhaService service,
    }) {
  final info = _ParsedCardInfo.fromBackendString(data.string);

  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,     // escurece o fundo
      barrierDismissible: false,        // fecha no botão "Sair" ou back
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) {
        return _CarteirinhaOverlay(
          nome: info.nome ?? '—',
          cpf: info.cpf ?? '',
          matricula: info.matricula ?? '',
          sexoTxt: info.sexoTxt ?? '—',
          nascimento: info.nascimento,
          token: data.token,
          expiresAtEpoch: data.expiresAtEpoch,
        );
      },
      transitionsBuilder: (_, anim, __, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    ),
  );
}

/// Tela transparente que ocupa toda a viewport, sem limites do bottom-sheet.
class _CarteirinhaOverlay extends StatelessWidget {
  final String nome;
  final String cpf;
  final String matricula;
  final String sexoTxt;
  final String? nascimento;
  final String token;
  final int? expiresAtEpoch;

  const _CarteirinhaOverlay({
    super.key,
    required this.nome,
    required this.cpf,
    required this.matricula,
    required this.sexoTxt,
    required this.nascimento,
    required this.token,
    required this.expiresAtEpoch,
  });

  @override
  Widget build(BuildContext context) {
    // Congela o text scale para o cartão não variar no Android.
    final mq = MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0));

    return WillPopScope(
      onWillPop: () async => true,
      child: Material(
        type: MaterialType.transparency,
        child: MediaQuery(
          data: mq,
          child: Stack(
            children: [
              // Camada de fundo apenas para consumir toques
              Positioned.fill(child: AbsorbPointer(absorbing: true, child: Container())),

              // Conteúdo centralizado e sem restrição de altura/largura do sheet
              Positioned.fill(
                child: Center(
                  child: SizedBox.expand(
                    // O DigitalCardView se ajusta via FittedBox internamente;
                    // aqui damos a área total para ele calcular a melhor escala.
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: ConstrainedBox(
                        // Limite “saudável” apenas para tablets/monitores muito grandes
                        constraints: const BoxConstraints(
                          maxWidth: 1400,
                          maxHeight: 1000,
                        ),
                        child: DigitalCardView(
                          nome: nome,
                          cpf: cpf,
                          matricula: matricula,
                          sexoTxt: sexoTxt,
                          nascimento: nascimento,
                          token: token,
                          expiresAtEpoch: expiresAtEpoch,
                          // força layout horizontal; em retrato ele gira 90°
                          forceLandscape: true,
                          forceLandscapeOnWide: true,
                          onClose: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parser do campo `string` vindo do backend.
class _ParsedCardInfo {
  final String? nome;
  final String? cpf;
  final String? matricula;
  final String? sexoTxt;
  final String? nascimento;

  const _ParsedCardInfo({
    this.nome,
    this.cpf,
    this.matricula,
    this.sexoTxt,
    this.nascimento,
  });

  factory _ParsedCardInfo.fromBackendString(String? s) {
    if (s == null || s.isEmpty) return const _ParsedCardInfo();

    String? nome, cpf, matricula, sexoTxt, nascimento;
    for (final raw in s.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('Titular:')) {
        nome = line.replaceFirst('Titular:', '').trim();
      } else if (line.startsWith('Beneficiário:')) {
        nome = line.replaceFirst('Beneficiário:', '').trim();
      } else if (line.startsWith('CPF:')) {
        cpf = line.replaceFirst('CPF:', '').trim();
      } else if (line.startsWith('Matrícula:')) {
        matricula = line.replaceFirst('Matrícula:', '').trim();
      } else if (line.startsWith('Sexo:')) {
        sexoTxt = line.replaceFirst('Sexo:', '').trim();
      } else if (line.startsWith('Nascimento:')) {
        nascimento = line.replaceFirst('Nascimento:', '').trim();
      }
    }
    return _ParsedCardInfo(
      nome: nome,
      cpf: cpf,
      matricula: matricula,
      sexoTxt: sexoTxt,
      nascimento: nascimento,
    );
  }
}
