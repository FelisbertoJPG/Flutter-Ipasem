// lib/ui/sheets/card_sheet.dart
import 'dart:async';
import 'dart:ui' show FontFeature; // necessário para FontFeature.tabularFigures()
import 'package:flutter/material.dart';
import '../../services/card_token_service.dart';
import '../../models/card_token_models.dart';

/// Abre o bottom sheet da Carteirinha.
/// [matricula] obrigatório; [idDependente]=0 para titular.
Future<void> showCardSheet(
    BuildContext context, {
      required int matricula,
      int idDependente = 0,
      CardTokenService? service,
    }) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _CardSheet(
      matricula: matricula,
      idDependente: idDependente,
      service: service ?? CardTokenService(),
    ),
  );
}

class _CardSheet extends StatefulWidget {
  const _CardSheet({
    required this.matricula,
    required this.idDependente,
    required this.service,
  });

  final int matricula;
  final int idDependente;
  final CardTokenService service;

  @override
  State<_CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends State<_CardSheet> {
  CardTokenResponse? _card;
  Object? _error;
  bool _loading = true;
  Timer? _tick;
  int _now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  @override
  void initState() {
    super.initState();
    _issue();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now().millisecondsSinceEpoch ~/ 1000);
    });
  }

  Future<void> _issue() async {
    try {
      final card = await widget.service.issueCardToken(
        matricula: widget.matricula,
        idDependente: widget.idDependente,
        generateOnClient: true,
      );
      // agenda expurgo “fire-and-forget”
      unawaited(widget.service.scheduleExpurgo(card));
      setState(() {
        _card = card;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topHandle = Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE5EE),
        borderRadius: BorderRadius.circular(2),
      ),
    );

    if (_loading) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(height: 8),
              Center(child: CircularProgressIndicator()),
              SizedBox(height: 16),
              Text('Emitindo carteirinha...'),
              SizedBox(height: 12),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              topHandle,
              const Text(
                'Carteirinha Digital',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD0C9)),
                ),
                child: Text(
                  'Falha ao emitir token.\n$_error',
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }

    final card = _card!;
    final int expTs = card.expiresAtEpoch;
    // normaliza restante como int sem usar clamp(num)
    final int rawRemain = expTs - _now;
    final int remain =
    rawRemain < 0 ? 0 : (rawRemain > (1 << 31) ? (1 << 31) : rawRemain);
    final String mm = (remain ~/ 60).toString().padLeft(2, '0');
    final String ss = (remain % 60).toString().padLeft(2, '0');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            topHandle,
            const Text(
              'Carteirinha Digital',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _CardView(card: card, mm: mm, ss: ss),
            const SizedBox(height: 10),
            // >>>> AQUI trocado de card.string -> card.infoString
            if (card.infoString != null && card.infoString!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6EDF3)),
                ),
                child: Text(
                  card.infoString!,
                  style: const TextStyle(fontSize: 12.5, height: 1.2),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card, required this.mm, required this.ss});

  final CardTokenResponse card;
  final String mm, ss;

  @override
  Widget build(BuildContext context) {
    final tokenStr = card.token;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF143C8D), Color(0xFF2A5699)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0B1220),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('IPASEM • Carteirinha', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Text(
              tokenStr,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text('Expira em $mm:$ss'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
