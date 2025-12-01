// lib/frontend/ui/components/carteirinha_overlay.dart
import 'package:flutter/material.dart';

import '../../../../common/models/card_token.dart';
import '../../../../common/services/carterinha_service/carteirinha_service.dart';
import 'digital_card_view.dart';

/// Exibe a carteirinha em overlay full-screen usando o rootNavigator.
/// Reaproveita o mesmo componente em todos os fluxos.
Future<void> showDigitalCardOverlay(
    BuildContext context, {
      required CardTokenData data,
    }) {
  final info = ParsedCardInfo.fromBackendString(data.string);
  final rootNav = Navigator.of(context, rootNavigator: true);

  return rootNav.push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) {
        return _DigitalCardOverlay(
          nome: info.nome ?? '—',
          cpf: info.cpf ?? '',
          matricula: info.matricula ?? '',
          sexoTxt: info.sexoTxt ?? '—',
          nascimento: info.nascimento,
          token: data.token,
          dbToken: data.dbToken,
          expiresAtEpoch: data.expiresAtEpoch,
          serverNowEpoch: data.serverNowEpoch,
        );
      },
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _DigitalCardOverlay extends StatefulWidget {
  final String nome;
  final String cpf;
  final String matricula;
  final String sexoTxt;
  final String? nascimento;
  final String token;
  final int? dbToken;
  final int? expiresAtEpoch;
  final int? serverNowEpoch;

  const _DigitalCardOverlay({
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
  State<_DigitalCardOverlay> createState() => _DigitalCardOverlayState();
}

class _DigitalCardOverlayState extends State<_DigitalCardOverlay> {
  bool _closing = false;
  bool _revoked = false;

  /// Revoga o token ao fechar (se tiver dbToken).
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

    // Canvas “fixo” para o FittedBox.
    const double baseW = 1280;
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
        dbToken: widget.dbToken,
        expiresAtEpoch: widget.expiresAtEpoch,
        serverNowEpoch: widget.serverNowEpoch,
        // Mantemos o card horizontal; quem gira é o pai.
        forceLandscape: true,
        forceLandscapeOnWide: false,
        onClose: _close,
      ),
    );

    // Em retrato, rotaciona o conteúdo em +90°.
    if (isPortrait) {
      card = RotatedBox(quarterTurns: 1, child: card);
    }

    return WillPopScope(
      onWillPop: () async {
        _close();
        return false; // quem faz o pop somos nós
      },
      child: Material(
        type: MaterialType.transparency,
        child: MediaQuery(
          data: mq,
          child: Stack(
            children: [
              const Positioned.fill(child: IgnorePointer()),
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
/// ÚNICO ponto de parse para evitar duplicação.
class ParsedCardInfo {
  final String? nome;
  final String? cpf;
  final String? matricula;
  final String? sexoTxt;
  final String? nascimento;

  const ParsedCardInfo({
    this.nome,
    this.cpf,
    this.matricula,
    this.sexoTxt,
    this.nascimento,
  });

  factory ParsedCardInfo.fromBackendString(String? s) {
    if (s == null || s.isEmpty) return const ParsedCardInfo();

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

    return ParsedCardInfo(
      nome: nome,
      cpf: cpf,
      matricula: matricula,
      sexoTxt: sexoTxt,
      nascimento: nascimento,
    );
  }
}
