// lib/ui/utils/print_helpers.dart
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/session.dart';
import '../../services/dev_api.dart';

import '../../repositories/reimpressao_repository.dart';

import '../../pdf/autorizacao_pdf_data.dart';
import '../../pdf/pdf_mappers.dart';
import '../../screens/pdf_preview_screen.dart';

/// Abre o preview/print do PDF a partir do número da autorização.
/// - Para EXAMES/COMPLEMENTARES usa AutorizacaoPdfData.fromReimpressaoExame
///   (o título do PDF sai correto).
/// - Para MÉDICA/ODONTOLÓGICA usa mapDetalheToPdfData com `tipo` apropriado.
Future<void> openPreviewFromNumero(
    BuildContext context,
    int numero, {
      bool useRootNavigator = false,
    }) async {
  try {
    final profile = await Session.getProfile();
    if (profile == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter o perfil do usuário.')),
      );
      return;
    }

    final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
        ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');

    final repo = ReimpressaoRepository(DevApi(baseUrl));
    final det = await repo.detalhe(numero, idMatricula: profile.id);
    if (det == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar os detalhes desta ordem.')),
      );
      return;
    }

    // Decide o "tipo" e mapeia para AutorizacaoPdfData
    AutorizacaoPdfData data;
    final isExames = det.tipoAutorizacao == 3; // 3 = exames/complementares

    if (isExames) {
      // EXAMES ou COMPLEMENTARES (subtipo 4)
      data = AutorizacaoPdfData.fromReimpressaoExame(
        det: det,
        idMatricula: profile.id,
        procedimentos: const [], // se tiver endpoint de AMBs, injete aqui
      );
    } else {
      // MÉDICA / ODONTOLÓGICA (heurística pelo código da especialidade)
      final tipo = (det.codEspecialidade == 700)
          ? AutorizacaoTipo.odontologica
          : AutorizacaoTipo.medica;

      data = mapDetalheToPdfData(
        det: det,
        nomeTitular: profile.nome,
        idMatricula: profile.id,
        procedimentos: const [],
        tipo: tipo, // <- obrigatório no mapper atualizado
      );
    }

    final fileName = 'aut_${det.numero}.pdf';
    if (!context.mounted) return;

    Navigator.of(context, rootNavigator: useRootNavigator).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          data: data,
          fileName: fileName,
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Falha ao abrir impressão: $e')),
    );
  }
}

/// Alias semântica para quem quiser chamar explicitamente “exame”.
Future<void> openPreviewFromNumeroExame(
    BuildContext context,
    int numero, {
      bool useRootNavigator = false,
    }) {
  return openPreviewFromNumero(context, numero, useRootNavigator: useRootNavigator);
}
