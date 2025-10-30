// lib/screens/carteirinha_flow.dart
import 'package:flutter/material.dart';

import '../models/card_token_models.dart';
import '../services/carteirinha_service.dart';
import 'carteirinha_beneficiary_sheet.dart';
import '../ui/widgets/digital_card_view.dart';

/// Inicia o fluxo completo:
/// 1) escolhe beneficiário
/// 2) carrega dados da pessoa
/// 3) emite token
/// 4) mostra o DigitalCardView como diálogo modal (root navigator)
Future<void> startCarteirinhaFlow(
    BuildContext context, {
      required int idMatricula,
    }) async {
  // 1) Beneficiário
  final idDep = await showBeneficiaryPickerSheet(
    context,
    idMatricula: idMatricula,
  );
  if (idDep == null) return;

  final svc = CarteirinhaService();

  // 2) Dados (titular + dependentes)
  Map<String, dynamic> dados;
  try {
    dados = await svc.carregarDados(idMatricula: idMatricula);
  } catch (e) {
    _toast(context, 'Falha ao carregar dados: $e');
    return;
  }

  final titular = (dados['titular'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  final deps    = (dados['dependentes'] as List?)?.cast<Map>() ?? const <Map>[];

  Map<String, dynamic> pessoa = idDep == 0
      ? titular
      : (deps.cast<Map<String, dynamic>>().firstWhere(
        (m) => (m['iddependente']?.toString() ?? '0') == idDep.toString(),
    orElse: () => const <String, dynamic>{},
  ));

  if (pessoa.isEmpty) pessoa = titular;

  // 3) Emissão
  CardTokenData token;
  try {
    token = await svc.emitir(matricula: idMatricula, iddependente: idDep.toString());
  } on CarteirinhaException catch (e) {
    _toast(context, e.message);
    return;
  } catch (_) {
    _toast(context, 'Falha ao emitir token.');
    return;
  }

  // 4) Diálogo modal no *root* navigator (garante que a barreira some ao fechar)
  await showGeneralDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'Carteirinha',
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogCtx, _, __) {
      return _CarteirinhaOverlay(
        pessoa: pessoa,
        token: token,
        onClose: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return Opacity(
        opacity: curved.value,
        child: Transform.scale(
          scale: 0.98 + 0.02 * curved.value,
          child: child,
        ),
      );
    },
  );
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class _CarteirinhaOverlay extends StatefulWidget {
  final Map<String, dynamic> pessoa;
  final CardTokenData token;
  final VoidCallback onClose;

  const _CarteirinhaOverlay({
    super.key,
    required this.pessoa,
    required this.token,
    required this.onClose,
  });

  @override
  State<_CarteirinhaOverlay> createState() => _CarteirinhaOverlayState();
}

class _CarteirinhaOverlayState extends State<_CarteirinhaOverlay> {
  final _svc = CarteirinhaService();

  @override
  void initState() {
    super.initState();
    // Agenda expurgo (não bloqueia a UI)
    final dbToken = widget.token.dbToken;
    if (dbToken != null) {
      Future.microtask(() async {
        try {
          await _svc.agendarExpurgo(dbToken);
        } catch (_) {
          // silencioso
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bloqueia back/gesto enquanto aberto (fecha só no botão "Sair")
    return WillPopScope(
      onWillPop: () async => false,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: DigitalCardView(
                nome: (widget.pessoa['nome'] ?? '').toString(),
                cpf: (widget.pessoa['cpf'] ?? '').toString(),
                matricula: (widget.pessoa['idmatricula'] ?? widget.pessoa['matricula'] ?? '').toString(),
                sexoTxt: (widget.pessoa['sexo_txt'] ?? widget.pessoa['sexo'] ?? '').toString(),
                nascimento: (widget.pessoa['dt_nasc'] ?? widget.pessoa['nascimento'])?.toString(),
                token: widget.token.token.toString(),
                expiresAtEpoch: widget.token.expiresAtEpoch,
                onClose: widget.onClose,
                // mantém horizontal em telas largas
                forceLandscapeOnWide: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
