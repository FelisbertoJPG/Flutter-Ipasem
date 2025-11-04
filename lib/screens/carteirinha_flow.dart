// lib/screens/carteirinha_flow.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../models/card_token_models.dart';
import '../services/carteirinha_service.dart';
import '../ui/widgets/digital_card_view.dart';

// Se existir a folha de escolha de beneficiário, mantenha o import.
// Caso não exista, remova o import e deixe depId = 0 no fluxo.
import 'carteirinha_beneficiary_sheet.dart';

/// Ponto único de entrada a partir do Home/Serviços.
/// - (Opcional) pergunta o beneficiário
/// - busca token ativo OU emite via CarteirinhaService
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

  // 2) Obtém token (reaproveita ativo; senão emite)
  final svc = CarteirinhaService.fromContext(context);
  CardTokenData? data;
  String? errMsg;

  final closeLoader = await _showBlockingLoader(context); // abre sem travar
  try {
    data = await svc.obterAtivoOuEmitir(
      matricula: idMatricula,
      iddependente: depId.toString(),
    );
  } on CarteirinhaException catch (e) {
    errMsg = e.message.isNotEmpty ? e.message : 'Falha ao emitir a carteirinha.';
  } catch (_) {
    errMsg = 'Falha ao emitir a carteirinha.';
  } finally {
    closeLoader(); // garante fechamento do loader mesmo com erro
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
}

typedef _Close = void Function();

/// Abre um loader bloqueante no ROOT sem travar o fluxo chamador.
/// Retorna uma função para fechá-lo com segurança.
Future<_Close> _showBlockingLoader(BuildContext context) async {
  final rootNav = Navigator.of(context, rootNavigator: true);
  bool closed = false;

  // Abre o diálogo em microtask para não bloquear a sequência.
  Future.microtask(() {
    showDialog<void>(
      context: context,
      useRootNavigator: true, // <- garante o mesmo stack do overlay
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

/// Abre a Carteirinha em rota transparente full-screen.
/// Evita restrições de altura do bottom-sheet no Android.
Future<void> _openDigitalCardOverlay(
    BuildContext context,
    CardTokenData data,
    ) {
  final info = _ParsedCardInfo.fromBackendString(data.string);
  final rootNav = Navigator.of(context, rootNavigator: true);

  return rootNav.push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) {
        return _CarteirinhaOverlay(
          nome: (info.nome ?? '—'),
          cpf: (info.cpf ?? ''),
          matricula: (info.matricula ?? ''),
          sexoTxt: (info.sexoTxt ?? '—'),
          nascimento: info.nascimento,
          token: data.token,
          dbToken: data.dbToken,                 // <— ESSENCIAL para revogar/expurgar
          expiresAtEpoch: data.expiresAtEpoch,
          serverNowEpoch: data.serverNowEpoch,   // <— usa relógio do servidor
        );
      },
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _CarteirinhaOverlay extends StatefulWidget {
  final String nome;
  final String cpf;
  final String matricula;
  final String sexoTxt;
  final String? nascimento;
  final String token;
  final int? dbToken;
  final int? expiresAtEpoch;
  final int? serverNowEpoch;

  const _CarteirinhaOverlay({
    super.key,
    required this.nome,
    required this.cpf,
    required this.matricula,
    required this.sexoTxt,
    required this.nascimento,
    required this.token,
    required this.expiresAtEpoch,
    this.dbToken,
    this.serverNowEpoch,
  });

  @override
  State<_CarteirinhaOverlay> createState() => _CarteirinhaOverlayState();
}

class _CarteirinhaOverlayState extends State<_CarteirinhaOverlay> {
  bool _closing = false;
  bool _revoked = false;

  // Revoga apenas quando o usuário fecha.
  Future<void> _revokeNow() async {
    if (_revoked) return;
    _revoked = true;

    final id = widget.dbToken ?? 0;
    if (id <= 0) return;

    try {
      final svc = CarteirinhaService.fromContext(context);
      await svc.excluirToken(dbToken: id);
    } catch (_) {
      // Silencioso: o expurgo agendado pelo DigitalCardView cobre se necessário.
    }
  }

  void _close() {
    if (_closing) return;
    _closing = true;

    // Dispara revogação (aguardando rapidamente para reduzir “tokens órfãos”).
    _revokeNow().whenComplete(() {
      final nav = Navigator.of(context, rootNavigator: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (nav.canPop()) nav.pop();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Congela text scale para não “estourar” fontes em Android.
    final mqBase = MediaQuery.of(context);
    final mq = mqBase.copyWith(textScaler: const TextScaler.linear(1.0));

    final size = mq.size;
    final isPortrait = size.height >= size.width;

    // Canvas de design fixo: base estável para o FittedBox escalar.
    const double baseW = 1280; // landscape
    const double baseH = 800;

    Widget card = SizedBox(
      width: baseW,
      height: baseH,
      child: DigitalCardView(
        nome: widget.nome,
        cpf: widget.cpf,
        matricula: widget.matricula,
        sexoTxt: widget.sexoTxt,
        nascimento: widget.nascimento,
        token: widget.token,
        dbToken: widget.dbToken,                   // <— DigitalCardView agenda expurgo
        expiresAtEpoch: widget.expiresAtEpoch,
        serverNowEpoch: widget.serverNowEpoch,
        // Mantemos o card em layout horizontal; quem gira é o PAI (modal).
        forceLandscape: true,
        forceLandscapeOnWide: false,
        onClose: _close,
      ),
    );

    // Em retrato, rotaciona o MODAL (conteúdo) em +90°.
    if (isPortrait) {
      card = RotatedBox(quarterTurns: 1, child: card);
    }

    return WillPopScope(
      onWillPop: () async {
        _close();
        return false; // nós mesmos controlamos o pop
      },
      child: Material(
        type: MaterialType.transparency,
        child: MediaQuery(
          data: mq,
          child: Stack(
            children: [
              // Fundo não-interativo
              const Positioned.fill(child: IgnorePointer()),
              // Conteúdo centralizado ocupando a viewport com escala correta
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: card,
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
