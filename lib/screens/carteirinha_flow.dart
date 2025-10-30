import 'dart:async';

import 'package:flutter/material.dart';
import '../models/card_token_models.dart';
import '../services/carteirinha_service.dart';
import '../services/dev_api.dart';
import '../models/dependent.dart';
import '../ui/widgets/digital_card_view.dart';
import 'carteirinha_beneficiary_sheet.dart';

/// Fluxo completo:
/// 1) Abre o sheet de beneficiários.
/// 2) Emite o token.
/// 3) Abre o DigitalCardView em OVERLAY bloqueante.
/// 4) Agenda expurgo depois de exibir.
Future<void> startCarteirinhaFlow(
    BuildContext context, {
      required int idMatricula,
      CarteirinhaService? service,
    }) async {
  // 1) escolher beneficiário
  final idDep = await showBeneficiaryPickerSheet(
    context,
    idMatricula: idMatricula,
  );
  if (idDep == null) return;

  // 2) emitir token (mostra aguarde curto)
  final svc = service ?? CarteirinhaService();
  CardTokenData tokenData;
  try {
    _showMiniLoading(context, 'Emitindo carteirinha...');
    tokenData = await svc.emitir(
      matricula: idMatricula,
      iddependente: idDep.toString(),
    );
  } finally {
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  // 2.1) carregar dados do beneficiário selecionado (nome/cpf/sexo/nasc)
  final api = buildDevApiFromEnv();
  final dep = await _loadSelectedDependent(api, idMatricula, idDep);

  // 3) abrir overlay bloqueante com o DigitalCardView
  await _showCardOverlay(
    context,
    nome: dep.nome,
    cpf: dep.cpf ?? '',
    matricula: '${dep.idmatricula}',
    sexoTxt: _sexoHumanizado(dep.sexo),
    nascimento: dep.dtNasc,
    token: '${tokenData.token}',
    expiresAtEpoch: tokenData.expiresAtEpoch,
  );

  // 4) agenda expurgo (fire-and-forget)
  if (tokenData.dbToken != null) {
    unawaited(svc.agendarExpurgo(tokenData.dbToken!));
  }
}

void _showMiniLoading(BuildContext context, String msg) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => WillPopScope(
      onWillPop: () async => false,
      child: const Center(child: CircularProgressIndicator()),
    ),
  );
}

Future<Dependent> _loadSelectedDependent(DevApi api, int idMatricula, int idDep) async {
  final list = await api.fetchDependentes(idMatricula);
  Dependent? d = list.where((e) => e.iddependente == idDep).cast<Dependent?>().firstWhere(
        (e) => e != null,
    orElse: () => null,
  );
  d ??= list.firstWhere(
        (e) => e.iddependente == 0,
    orElse: () => Dependent(
      nome: 'Titular',
      idmatricula: idMatricula,
      iddependente: 0,
      sexo: 'M',
      cpf: '',
      dtNasc: null,
      idade: null,
    ),
  );
  return d!;
}

String _sexoHumanizado(String? s) {
  final v = (s ?? '').trim().toUpperCase();
  if (v == 'F' || v == 'FEMININO' || v == '2') return 'FEMININO';
  return 'MASCULINO';
}

Future<void> _showCardOverlay(
    BuildContext context, {
      required String nome,
      required String cpf,
      required String matricula,
      required String sexoTxt,
      required String? nascimento,
      required String token,
      required int? expiresAtEpoch,
    }) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false, // bloqueia ações abaixo
    barrierLabel: 'Carteirinha',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, __) {
      final mq = MediaQuery.of(ctx);
      final noScale = mq.copyWith(textScaler: const TextScaler.linear(1.0));

      // Caixa central com o card – sem “faixa zebrada”
      return MediaQuery(
        data: noScale,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 980, // acompanha o design landscape do widget
              maxHeight: 700,
            ),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: Colors.transparent,
                  child: DigitalCardView(
                    nome: nome,
                    cpf: cpf,
                    matricula: matricula,
                    sexoTxt: sexoTxt,
                    nascimento: nascimento,
                    token: token,
                    expiresAtEpoch: expiresAtEpoch,
                    // Fechar somente pelo botão "Sair"
                    onClose: () => Navigator.of(ctx).pop(),
                    // Mantém a rotação automática do próprio widget
                    forceLandscape: false,
                    forceLandscapeOnWide: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
