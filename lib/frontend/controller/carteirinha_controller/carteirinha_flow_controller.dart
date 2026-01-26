// lib/frontend/screens/carteirinha_flow_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../../../common/models/card_token.dart';
import '../../../common/services/carterinha_service/carteirinha_service.dart';
import '../../views/components/carterinha_comp/carteirinha_overlay.dart';
import '../../views/components/carterinha_comp/carteirinha_selecionar_beneficiario.dart';


/// Ponto único de entrada a partir do Home/Serviços.
/// - (Opcional) pergunta o beneficiário
/// - busca token ativo OU emite via CarteirinhaService
/// - abre o cartão em overlay full-screen
Future<void> startCarteirinhaFlow(
    BuildContext context, {
      required int idMatricula,
    }) async {
  // 1) Escolha do beneficiário (se houver sheet no projeto)
  int depId = 0;
  try {
    final chosen = await showBeneficiaryPickerSheet(
      context,
      idMatricula: idMatricula,
    );
    if (chosen == null) return; // cancelou
    depId = chosen;
  } catch (_) {
    // sem sheet -> segue como titular (depId = 0)
  }

  // 2) Obtém token (reaproveita ativo; senão emite)
  final svc = CarteirinhaService.fromContext(context);
  CardTokenData? data;
  String? errMsg;

  final closeLoader = await _showBlockingLoader(context);
  try {
    data = await svc.obterAtivoOuEmitir(
      matricula: idMatricula,
      iddependente: depId.toString(),
    );
  } on CarteirinhaException catch (e) {
    errMsg =
    e.message.isNotEmpty ? e.message : 'Falha ao emitir a carteirinha.';
  } catch (_) {
    errMsg = 'Falha ao emitir a carteirinha.';
  } finally {
    closeLoader();
  }

  if (data == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errMsg ?? 'Erro inesperado ao emitir.')),
      );
    }
    return;
  }

  // 3) Usa o overlay único
  await showDigitalCardOverlay(context, data: data);
}

typedef _Close = void Function();

/// Loader bloqueante no rootNavigator, retornando função de fechamento.
Future<_Close> _showBlockingLoader(BuildContext context) async {
  final rootNav = Navigator.of(context, rootNavigator: true);
  bool closed = false;

  Future.microtask(() {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  });

  return () {
    if (!closed) {
      closed = true;
      if (rootNav.canPop()) rootNav.pop();
    }
  };
}
