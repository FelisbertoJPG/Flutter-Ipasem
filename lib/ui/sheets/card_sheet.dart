// lib/ui/sheets/card_sheet.dart
import 'package:flutter/material.dart';

import '../../models/card_token_models.dart';
import '../../services/carteirinha_service.dart';
import '../widgets/digital_card_view.dart';

/// Abre o bottom-sheet exibindo o cartão digital.
/// Mantém a mesma assinatura pública.
Future<void> showDigitalCardSheet(
    BuildContext context, {
      required CardTokenData data,
      required CarteirinhaService service,
    }) {
  // Extrai os campos de exibição a partir de data.string
  final info = _ParsedCardInfo.fromBackendString(data.string);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DigitalCardView(
              nome: info.nome ?? '—',
              cpf: info.cpf ?? '',
              matricula: info.matricula ?? '',
              sexoTxt: info.sexoTxt ?? '—',
              nascimento: info.nascimento, // já vem dd/mm/aaaa do backend
              token: data.token,
              expiresAtEpoch: data.expiresAtEpoch,
              onClose: () => Navigator.of(ctx).maybePop(), forceLandscape: false,
            ),
            const SizedBox(height: 16),
            // Opcional: manter botão "Fechar" fora do cartão
            Align(
              alignment: Alignment.center,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).maybePop(),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Estrutura simples para segurar os dados parseados do backend.
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

  /// Constrói a partir do campo `string` retornado pelo gateway:
  /// Ex. (titular)
  ///   Titular: NOME
  ///   CPF: 000.000.000-00
  ///   Matrícula: 6542
  ///   Sexo: Masculino
  ///   Nascimento: 04/12/1972
  ///   Token: 12345678
  ///
  /// ou (dependente) com "Beneficiário:" e "Dependente: X".
  factory _ParsedCardInfo.fromBackendString(String? s) {
    if (s == null || s.isEmpty) return const _ParsedCardInfo();

    String? nome;
    String? cpf;
    String? matricula;
    String? sexoTxt;
    String? nascimento;

    final lines = s.split('\n');

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('Titular:')) {
        nome = line.replaceFirst('Titular:', '').trim();
        continue;
      }
      if (line.startsWith('Beneficiário:')) {
        nome = line.replaceFirst('Beneficiário:', '').trim();
        continue;
      }
      if (line.startsWith('CPF:')) {
        cpf = line.replaceFirst('CPF:', '').trim();
        continue;
      }
      if (line.startsWith('Matrícula:')) {
        matricula = line.replaceFirst('Matrícula:', '').trim();
        continue;
      }
      if (line.startsWith('Sexo:')) {
        sexoTxt = line.replaceFirst('Sexo:', '').trim();
        continue;
      }
      if (line.startsWith('Nascimento:')) {
        nascimento = line.replaceFirst('Nascimento:', '').trim();
        continue;
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
