// lib/frontend/views/ui/utils/print_helpers.dart
import 'package:flutter/material.dart';

import '../../../../backend/controller/pdf_controller/autorizacao_pdf_data.dart';
import '../../../../backend/controller/pdf_controller/pdf_mappers.dart';
import '../../../../common/models/proc_item.dart';
import '../../../../common/models/reimpressao.dart';
import '../../../../common/repositories/exames_repository.dart';
import '../../../../common/repositories/reimpressao_repository.dart';
import '../../../../common/config/dev_api.dart';
import '../../../../common/services/session.dart';
import '../../../../common/state/auth_events.dart';
import '../../screens/pdf_preview_screen.dart';

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
        const SnackBar(
          content: Text('Não foi possível obter o perfil do usuário.'),
        ),
      );
      return;
    }

    // Client HTTP central: base = ApiRouter.apiRootUri (ex.: https://host/api/v1)
    final api = DevApi();
    final reimpRepo = ReimpressaoRepository(api);
    final exRepo = ExamesRepository(api);

    // --- 1) Pega payload bruto (dados + itens) ---
    final payload = await reimpRepo.detalheRaw(
      numero,
      idMatricula: profile.id,
    );

    final Map<String, dynamic> dadosMap = ((
        (payload['data'] as Map?)?['dados'] ??
            (payload['dados']) ??
            (payload['row']) ??
            payload
    ) as Map)
        .cast<String, dynamic>();

    final det = ReimpressaoDetalhe.fromMap(dadosMap);
    final bool isExame = _ehExamesPeloDetalhe(det);

    // --- 2) Monta AutorizacaoPdfData ---
    late AutorizacaoPdfData data;

    if (isExame) {
      // coleta itens do payload e converte para ProcItem
      final rawItens = ((payload['data'] as Map?)?['itens'] ??
          payload['itens'] ??
          const []) as List;

      final procedimentos = rawItens
          .whereType<Map>()
          .map((m) => ProcItem.fromMap(m.cast<String, dynamic>()))
          .where((p) => p.codigo.isNotEmpty || p.descricao.isNotEmpty)
          .toList();

      data = AutorizacaoPdfData.fromReimpressaoExame(
        det: det,
        idMatricula: profile.id,
        procedimentos: procedimentos,
      );

      if (data.procedimentos.isEmpty) {
        throw StateError(
          'Nenhum procedimento informado para a autorização ${data.numero}.',
        );
      }
    } else {
      // médica/odonto seguem seu mapper existente
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

    // --- 3) Abre o preview ---
    final fileName = 'aut_$numero.pdf';
    await Navigator.of(context, rootNavigator: useRootNavigator).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          data: data,
          fileName: fileName,
        ),
      ),
    );

    // --- 4) Ao fechar o preview, marcar A→R para Exames ---
    if (isExame) {
      try {
        await exRepo.registrarPrimeiraImpressao(numero);
        AuthEvents.instance.emitPrinted(numero);
        AuthEvents.instance.emitStatusChanged(numero, 'R');
      } catch (_) {
        // silencioso
      }
    } else {
      AuthEvents.instance.emitPrinted(numero);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Falha ao abrir impressão: $e')),
    );
  }
}

Future<void> openPreviewFromNumeroExame(
    BuildContext context,
    int numero, {
      bool useRootNavigator = false,
    }) {
  return openPreviewFromNumero(
    context,
    numero,
    useRootNavigator: useRootNavigator,
  );
}

// mesma regra do backend
bool _ehExamesPeloDetalhe(ReimpressaoDetalhe det) {
  final t = det.tipoAutorizacao;
  final sub = det.codSubtipoAutorizacao;
  return t == 2 || t == 7 || (t == 3 && sub == 4);
}
