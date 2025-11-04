// lib/ui/components/consent_dialog.dart
import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class ConsentDialog extends StatefulWidget {
  const ConsentDialog({
    super.key,
    required this.onOpenPrivacy,
    required this.onOpenTerms,
  });

  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenTerms;

  static Future<bool?> show(
      BuildContext context, {
        required VoidCallback onOpenPrivacy,
        required VoidCallback onOpenTerms,
      }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConsentDialog(
        onOpenPrivacy: onOpenPrivacy,
        onOpenTerms: onOpenTerms,
      ),
    );
  }

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Termos de Uso do IpasemNH Digital'),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            const Text(
              'Para continuar, confirme que leu e aceita a '
                  'Política de Privacidade e os Termos de Uso.',
              style: TextStyle(height: 1.35),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onOpenPrivacy,
              child: const Text('Ver Política de Privacidade'),
            ),
            TextButton(
              onPressed: widget.onOpenTerms,
              child: const Text('Ver Termos de Uso'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _checked,
                  onChanged: (v) => setState(() => _checked = v ?? false),
                ),
                const Expanded(
                  child: Text('Li e aceito os termos acima.'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kBrand),
          onPressed: _checked ? () => Navigator.pop(context, true) : null,
          child: const Text('Concordo e continuar'),
        ),
      ],
    );
  }
}
