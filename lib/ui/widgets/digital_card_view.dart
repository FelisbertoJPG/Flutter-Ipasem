// lib/ui/widgets/digital_card_view.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../models/card_token_models.dart';
import '../../services/card_token_service.dart';

/// Widget de visualização da Carteirinha Digital.
/// - UI pura com contagem regressiva
/// - Agenda expurgo ao abrir (via service.scheduleExpurgo)
class DigitalCardView extends StatefulWidget {
  final CardTokenResponse card;
  final CardTokenService service;

  const DigitalCardView({
    super.key,
    required this.card,
    required this.service,
  });

  @override
  State<DigitalCardView> createState() => _DigitalCardViewState();
}

class _DigitalCardViewState extends State<DigitalCardView> {
  Timer? _tick;
  Duration _remain = Duration.zero;
  bool _scheduled = false;
  Map<String, dynamic>? _lastValidation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    _remain = widget.card.remaining;

    // agenda expurgo apenas após abrir
    _scheduleIfNeeded();

    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _remain = widget.card.remaining);
      if (_remain.inSeconds <= 0) _validateSilentlyOnce();
    });
  }

  Future<void> _scheduleIfNeeded() async {
    if (_scheduled) return;
    _scheduled = true;
    await widget.service.scheduleExpurgo(widget.card);
    unawaited(widget.service.getScheduleStatus(widget.card)); // opcional
  }

  Future<void> _validateSilentlyOnce() async {
    if (_lastValidation != null) return;
    try {
      final v = await widget.service.validate(widget.card);
      if (!mounted) return;
      setState(() => _lastValidation = v);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tick?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expired = widget.card.isExpired;
    final remainStr = _fmt(_remain);

    return Scaffold(
      appBar: AppBar(title: const Text('Carteirinha Digital'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              _InfoTile(label: 'Beneficiário', value: _extractName(widget.card.infoString)),
              const SizedBox(height: 12),
              _MonoPanel(text: widget.card.infoString ?? ''),
              const SizedBox(height: 16),
              _TokenBadge(token: widget.card.token),
              const SizedBox(height: 16),
              _CountdownBar(
                remaining: _remain,
                total: Duration(seconds: widget.card.ttlSeconds),
                expired: expired,
              ),
              const SizedBox(height: 8),
              Text(
                expired ? 'Expirado' : 'Expira em $remainStr',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: expired ? theme.colorScheme.error : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    final v = await widget.service.validate(widget.card);
                    if (!mounted) return;
                    setState(() => _lastValidation = v);
                    final exists = v['exists'] == true;
                    final expiredFromApi = v['expired'] == true;
                    final msg =
                    exists ? (expiredFromApi ? 'Token existente, porém expirado.' : 'Token válido.') : 'Token não encontrado.';
                    _snack(context, msg);
                  } catch (_) {
                    if (!mounted) return;
                    _snack(context, 'Falha na validação');
                  }
                },
                icon: const Icon(Icons.verified),
                label: const Text('Validar agora'),
              ),
              if (_lastValidation != null) ...[
                const SizedBox(height: 12),
                _MonoPanel(text: _pretty(_lastValidation!)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _extractName(String? s) {
    if (s == null) return '';
    for (final l in s.split('\n')) {
      if (l.startsWith('Titular: ') || l.startsWith('Beneficiário: ')) return l;
    }
    return '';
  }

  static void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
  static String _fmt(Duration d) {
    final s = d.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  static String _pretty(Map<String, dynamic> m) {
    final b = StringBuffer();
    m.forEach((k, v) => b.writeln('$k: $v'));
    return b.toString().trim();
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: th.colorScheme.surfaceVariant.withOpacity(0.4),
      ),
      child: Row(children: [
        Text('$label: ', style: th.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        Expanded(child: Text(value)),
      ]),
    );
  }
}

class _MonoPanel extends StatelessWidget {
  final String text;
  const _MonoPanel({required this.text});
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: th.colorScheme.outlineVariant),
      ),
      child: Text(text, style: const TextStyle(fontFamily: 'monospace', height: 1.25)),
    );
  }
}

class _TokenBadge extends StatelessWidget {
  final String token;
  const _TokenBadge({required this.token});
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(width: 1.2, color: th.colorScheme.primary),
      ),
      child: Row(children: [
        const Icon(Icons.qr_code_2, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            token,
            textAlign: TextAlign.center,
            style: th.textTheme.headlineSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ]),
    );
  }
}

class _CountdownBar extends StatelessWidget {
  final Duration remaining, total;
  final bool expired;
  const _CountdownBar({required this.remaining, required this.total, required this.expired});

  @override
  Widget build(BuildContext context) {
    final totalMs = total.inMilliseconds.clamp(1, 1 << 31);
    final leftMs = remaining.inMilliseconds.clamp(0, totalMs);
    final frac = leftMs / totalMs;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(value: expired ? 0.0 : frac, minHeight: 10),
    );
  }
}
