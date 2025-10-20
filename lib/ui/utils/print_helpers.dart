// lib/ui/utils/print_helpers.dart
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/dev_api.dart';
import '../../services/session.dart';

import '../../repositories/reimpressao_repository.dart';
import '../../repositories/exames_repository.dart';

import '../../pdf/autorizacao_pdf_data.dart';
import '../../pdf/pdf_mappers.dart';
import '../../screens/pdf_preview_screen.dart';

/// Abre o preview/print do PDF a partir do número da autorização.
/// - EXAMES/COMPLEMENTARES: tenta Reimpressão; se vier vazio, faz fallback
///   para `exame_consulta` e ainda assim gera o PDF no app.
/// - MÉDICA/ODONTOLÓGICA: usa o mapper `mapDetalheToPdfData` com `tipo` correto.
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

    final api  = DevApi(baseUrl);
    final repo = ReimpressaoRepository(api);

    final det = await repo.detalhe(numero, idMatricula: profile.id);

    AutorizacaoPdfData? data;
    if (det != null) {
      final isExames = det.tipoAutorizacao == 3;
      if (isExames) {
        data = AutorizacaoPdfData.fromReimpressaoExame(
          det: det,
          idMatricula: profile.id,
          procedimentos: const [],
        );
      } else {
        final tipo = (det.codEspecialidade == 700)
            ? AutorizacaoTipo.odontologica
            : AutorizacaoTipo.medica;
        data = mapDetalheToPdfData(
          det: det,
          nomeTitular: profile.nome,
          idMatricula: profile.id,
          procedimentos: const [],
          tipo: tipo,
        );
      }
    }

    if (data == null) {
      data = await _fallbackExameFromConsulta(
        api: api,
        numero: numero,
        idMatricula: profile.id,
        nomeTitular: profile.nome,
      );
    }

    if (data == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar os detalhes desta ordem.')),
      );
      return;
    }

    final fileName = 'aut_$numero.pdf';
    if (!context.mounted) return;

    // >>> AGORA AGUARDA O FECHAMENTO DO PREVIEW <<<
    await Navigator.of(context, rootNavigator: useRootNavigator).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          data: data!,
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

/// Fallback para EXAMES quando o endpoint de Reimpressão não retorna dados.
/// Usa `exame_consulta` e monta um PDF mínimo de Exames.
Future<AutorizacaoPdfData?> _fallbackExameFromConsulta({
  required DevApi api,
  required int numero,
  required int idMatricula,
  required String nomeTitular,
}) async {
  try {
    final exRepo = ExamesRepository(api);
    final det = await exRepo.consultarDetalhe(
      numero: numero,
      idMatricula: idMatricula,
    );

    return AutorizacaoPdfData(
      tipo: AutorizacaoTipo.exames,
      numero: numero,

      // Prestador
      nomePrestador: det.prestador,
      codPrestador: '', // não disponível neste endpoint
      especialidade: det.especialidade.isEmpty ? 'EXAMES' : det.especialidade,
      endereco: det.endereco,
      bairro: det.bairro,
      cidade: det.cidade,
      telefone: det.telefone,
      codigoVinculo: '',
      nomeVinculo: '',

      // Segurado/Paciente
      idMatricula: idMatricula,
      nomeTitular: nomeTitular,
      idDependente: 0,
      nomePaciente: det.paciente,
      idadePaciente: '',

      // Metadados
      dataEmissao: det.dataEmissao,
      codigoEspecialidade: 0,
      observacoes: det.observacoes ?? '',
      percentual: null,
      primeiraImpressao: false,
      procedimentos: const [],
    );
  } catch (_) {
    return null;
  }
}
