// lib/widgets/digital_card_view.dart
import 'package:flutter/material.dart';

import '../../models/card_token_models.dart';
import '../../services/card_token_service.dart';
import '../../services/carteirinha_service.dart';

class DigitalCardView extends StatefulWidget {
  final CardTokenData data;
  final CarteirinhaService service;

  const DigitalCardView({
    super.key,
    required this.data,
    required this.service,
  });

  @override
  State<DigitalCardView> createState() => _DigitalCardViewState();
}

class _DigitalCardViewState extends State<DigitalCardView> {
  late final CardTokenController _controller;
  int _secs = 0;

  @override
  void initState() {
    super.initState();
    _controller = CardTokenController(service: widget.service, data: widget.data);
    _controller.secondsLeftStream.listen((v) {
      if (mounted) setState(() => _secs = v);
    });
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fmtSecs(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final token = widget.data.token;
    final sexoTxt = widget.data.sexoTxt ?? '-';
    final pretty = widget.data.prettyString ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Carteirinha Digital', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(pretty.isNotEmpty ? pretty : 'Token: $token'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Sexo: $sexoTxt', style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  Icon(Icons.timer_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(_fmtSecs(_secs), style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Token ${widget.data.dbToken} (expira automaticamente)',
          style: theme.textTheme.labelMedium,
        ),
      ],
    );
  }
}
