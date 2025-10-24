// lib/ui/utils/print_helpers.dart
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/dev_api.dart';
import '../../services/session.dart';

import '../../repositories/reimpressao_repository.dart';
import '../../repositories/exames_repository.dart';

import '../../models/reimpressao.dart';
import '../../pdf/autorizacao_pdf_data.dart';
import '../../pdf/pdf_mappers.dart';
import '../../screens/pdf_preview_screen.dart';

// Eventos globais (home/histórico escutam isso)
import '../../state/auth_events.dart';

/// Abre o preview/print do PDF a partir do número da autorização.
/// Regras:
/// - Gera o PDF localmente (sem acessar reimpressao_pdf no servidor).
/// - Se for EXAMES, marca A→R apenas quando o usuário FECHAR o preview.
/// - Emite eventos globais ao concluir, para forçar atualização dos cards.
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

    final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl ??
        const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');

    final api       = DevApi(baseUrl);
    final reimpRepo = ReimpressaoRepository(api);
    final exRepo    = ExamesRepository(api);

    // 1) Tenta obter os dados completos pela Reimpressão
    final det = await reimpRepo.detalhe(numero, idMatricula: profile.id);

    AutorizacaoPdfData? data;
    bool isExame = false;

    if (det != null) {
      // Heurística de “exames/complementares”
      isExame = _ehExamesPeloDetalhe(det);

      if (isExame) {
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

    // 2) Se não achou nada na Reimpressão e a ordem for de Exames, usa o fallback
    data ??= await _fallbackExameFromConsulta(
      api: api,
      numero: numero,
      idMatricula: profile.id,
      nomeTitular: profile.nome,
    );
    isExame = isExame || (data?.tipo == AutorizacaoTipo.exames);

    if (data == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar os detalhes desta autorização.')),
      );
      return;
    }

    final fileName = 'aut_$numero.pdf';

    // 3) Abre o preview local (sem alterar status ainda)
    await Navigator.of(context, rootNavigator: useRootNavigator).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          data: data!,
          fileName: fileName,
        ),
      ),
    );

    // 4) Ao FECHAR o preview: se for EXAMES, marca A→R e emite eventos
    if (isExame) {
      try {
        await exRepo.registrarPrimeiraImpressao(numero);
        AuthEvents.instance.emitPrinted(numero);
        AuthEvents.instance.emitStatusChanged(numero, 'R');
      } catch (_) {
        // silencioso: não bloquear a volta da tela
      }
    } else {
      // Para os demais tipos, ainda assim força refresh visual do histórico
      AuthEvents.instance.emitPrinted(numero);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Falha ao abrir impressão: $e')),
    );
  }
}

/// Alias semântico quando a chamada for explicitamente de exame.
Future<void> openPreviewFromNumeroExame(
    BuildContext context,
    int numero, {
      bool useRootNavigator = false,
    }) {
  return openPreviewFromNumero(context, numero, useRootNavigator: useRootNavigator);
}

/// Heurística compatível com backend para classificar EXAMES.
/// - tipo_autorizacao == 2      -> exames
/// - tipo_autorizacao == 7      -> fisioterapia (usa regra de exames)
/// - tipo_autorizacao == 3 && codsubtipo_autorizacao == 4 -> complementares (exames)
bool _ehExamesPeloDetalhe(ReimpressaoDetalhe det) {
  final t = det.tipoAutorizacao;
  final sub = det.codSubtipoAutorizacao;
  return t == 2 || t == 7 || (t == 3 && sub == 4);
}

/// Fallback para EXAMES quando o endpoint de Reimpressão não retorna dados.
/// Usa `exame_consulta` e monta um PDF mínimo de Exames (preview interno).
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
      codPrestador: '',
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
