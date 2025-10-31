// lib/screens/carteirinha_flow.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../models/card_token_models.dart';
import '../services/carteirinha_service.dart';
import '../ui/widgets/digital_card_view.dart';

// Se existir a folha de escolha de beneficiário, mantenha o import.
// Caso não exista, remova o import e deixe depId = 0 no fluxo.
import 'carteirinha_beneficiary_sheet.dart';

/// Ponto único de entrada a partir do HomeServicos.
/// - (Opcional) pergunta o beneficiário
/// - emite o token via CarteirinhaService.emitir()
/// - abre o cartão em overlay full-screen (sem bottom-sheet)
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

  // 2) Emite token (com loader que SEMPRE fecha)
  final svc = CarteirinhaService();
  CardTokenData? data;
  String? errMsg;

  final closeLoader = await _showBlockingLoader(context); // <-- abre sem await do diálogo
  try {
    data = await svc.emitir(
      matricula: idMatricula,
      iddependente: depId.toString(),
    );
  } on CarteirinhaException catch (e) {
    errMsg = e.message.isNotEmpty ? e.message : 'Falha ao emitir a carteirinha.';
  } catch (_) {
    errMsg = 'Falha ao emitir a carteirinha.';
  } finally {
    closeLoader(); // <-- garante que o loader fecha mesmo com erro
  }

  if (data == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errMsg ?? 'Erro inesperado ao emitir.')),
      );
    }
    return;
  }

  // 3) Abre overlay full-screen (sem limitações de bottom-sheet)
  await _openDigitalCardOverlay(context, data);

  // 4) (Opcional) agenda expurgo após exibir o cartão (silencioso)
  try {
    await svc.agendarExpurgo(data.dbToken);
  } catch (_) {/* silencioso */}
}

typedef _Close = void Function();

/// Abre um loader bloqueante sem travar o fluxo chamador.
/// Retorna uma função para fechá-lo de qualquer lugar (e sempre com segurança).
Future<_Close> _showBlockingLoader(BuildContext context) async {
  final nav = Navigator.of(context, rootNavigator: true);
  bool closed = false;

  // Abre o diálogo em um microtask para não bloquear a sequência.
  Future.microtask(() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  });

  return () {
    if (!closed) {
      closed = true;
      nav.maybePop();
    }
  };
}

/// Abre a Carteirinha em rota transparente full-screen.
/// Evita restrições de altura do bottom-sheet no Android.
Future<void> _openDigitalCardOverlay(
    BuildContext context,
    CardTokenData data,
    ) {
  final info = _ParsedCardInfo.fromBackendString(data.string);

  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,
      barrierDismissible: false,
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
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

/// Tela transparente que ocupa toda a viewport, dando espaço total
/// para o DigitalCardView rotacionar 90° em tela retrato.
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
    // Congela text scale para não “estourar” fontes em Android.
    final mq = MediaQuery.of(context).copyWith(
      textScaler: const TextScaler.linear(1.0),
    );

    return WillPopScope(
      onWillPop: () async => true,
      child: Material(
        type: MaterialType.transparency,
        child: MediaQuery(
          data: mq,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {}, // toque fora não fecha
                  child: Container(color: Colors.transparent),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: ConstrainedBox(
                      // Limites só para telas gigantes; não afeta phones.
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
