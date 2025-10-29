// lib/sheets/card_sheet.dart
import 'package:flutter/material.dart';

import '../../models/card_token_models.dart';
import '../../services/carteirinha_service.dart';
import '../widgets/digital_card_view.dart';

Future<void> showDigitalCardSheet(
    BuildContext context, {
      required CardTokenData data,
      required CarteirinhaService service,
    }) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DigitalCardView(data: data, service: service),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).maybePop(),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
