import 'package:flutter/material.dart';

enum AppAlertType { info, success, warning, error }

class AppAlert {
  static Color _color(BuildContext ctx, AppAlertType t) {
    final cs = Theme.of(ctx).colorScheme;
    switch (t) {
      case AppAlertType.success:
        return cs.secondary;
      case AppAlertType.warning:
        return Colors.amber.shade700;
      case AppAlertType.error:
        return cs.error;
      case AppAlertType.info:
        return cs.primary;
    }
  }

  static IconData _icon(AppAlertType t) {
    switch (t) {
      case AppAlertType.success:
        return Icons.check_circle_outline;
      case AppAlertType.warning:
        return Icons.warning_amber_outlined;
      case AppAlertType.error:
        return Icons.error_outline;
      case AppAlertType.info:
        return Icons.info_outline;
    }
  }

  static Future<void> show(
      BuildContext context, {
        required String title,
        required String message,
        AppAlertType type = AppAlertType.info,
        String okLabel = 'OK',
        VoidCallback? onOk,
        bool barrierDismissible = true,
        bool useRootNavigator = false, // <<< importante p/ nested nav
      }) {
    final color = _color(context, type);
    final icon = _icon(type);

    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 8),
            Flexible(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onOk?.call();
            },
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }

  /// Mostra o número da autorização. Quando [pendente] for true (caso Exames),
  /// esconde o botão "Abrir impressão" e exibe um aviso de análise.
  static Future<void> showAuthNumber(
      BuildContext context, {
        required int numero,
        String title = 'Autorização emitida',
        VoidCallback? onOk,
        VoidCallback? onOpenPreview, // navega para a tela de impressão
        bool barrierDismissible = false,
        bool useRootNavigator = false, // importante p/ nested nav

        // --- NOVOS ---
        bool pendente = false,
        String? pendenteMsg,
      }) {
    final bool isPendente = pendente;
    final Color color =
    _color(context, isPendente ? AppAlertType.warning : AppAlertType.success);
    final IconData leadingIcon =
    isPendente ? Icons.hourglass_bottom_outlined : Icons.check_circle_outline;
    final String effectiveTitle = isPendente ? 'Autorização enviada' : title;

    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(leadingIcon, size: 24, color: color),
            const SizedBox(width: 8),
            Flexible(child: Text(effectiveTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Número da autorização:'),
            const SizedBox(height: 8),
            SelectableText(
              '$numero',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            if (isPendente) ...[
              const SizedBox(height: 12),
              Text(
                pendenteMsg ??
                    'Autorização enviada para análise.\nPrevisão de até 48h.',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!isPendente && onOpenPreview != null)
            TextButton.icon(
              icon: const Icon(Icons.print_outlined),
              label: const Text('Abrir impressão'),
              onPressed: () {
                Navigator.of(ctx).pop(); // fecha o diálogo
                onOpenPreview(); // navega para o preview/print
              },
            ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onOk?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
