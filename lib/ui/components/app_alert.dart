import 'package:flutter/material.dart';

enum AppAlertType { info, success, warning, error }

class AppAlert {
  static Color _color(BuildContext ctx, AppAlertType t) {
    final cs = Theme.of(ctx).colorScheme;
    switch (t) {
      case AppAlertType.success: return cs.secondary;
      case AppAlertType.warning: return Colors.amber.shade700;
      case AppAlertType.error:   return cs.error;
      case AppAlertType.info:    return cs.primary;
    }
  }

  static IconData _icon(AppAlertType t) {
    switch (t) {
      case AppAlertType.success: return Icons.check_circle_outline;
      case AppAlertType.warning: return Icons.warning_amber_outlined;
      case AppAlertType.error:   return Icons.error_outline;
      case AppAlertType.info:    return Icons.info_outline;
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
    final icon  = _icon(type);

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

  static Future<void> showAuthNumber(
      BuildContext context, {
        required int numero,
        String title = 'Autorização emitida',
        VoidCallback? onOk,
        bool barrierDismissible = false,
        bool useRootNavigator = false, // <<< importante p/ nested nav
      }) {
    final color = _color(context, AppAlertType.success);

    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 24, color: color),
            const SizedBox(width: 8),
            Flexible(child: Text(title)),
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
          ],
        ),
        actions: [
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
