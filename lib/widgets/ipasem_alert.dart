import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Tipos de alerta (só para mapear ícone/cor rapidamente)
enum IpasemAlertType { info, success, warning, error, loading }

class IpasemAlertOverlay extends StatelessWidget {
  final String message;
  final IpasemAlertType type;

  /// Cor do “badge” (bolinha) e do spinner. Se null, usamos a cor pelo [type].
  final Color? accentColor;

  /// Mostra um CircularProgress quando for loading
  final bool showProgress;

  const IpasemAlertOverlay({
    super.key,
    required this.message,
    this.type = IpasemAlertType.info,
    this.accentColor,
    this.showProgress = false,
  });

  // Cores e ícones padrão por tipo
  (IconData, Color) _styleByType(BuildContext ctx) {
    const brandBlue = Color(0xFF143C8D);
    switch (type) {
      case IpasemAlertType.success:
        return (Icons.check, const Color(0xFF2E7D32));
      case IpasemAlertType.warning:
        return (Icons.warning_amber_rounded, const Color(0xFFF9A825));
      case IpasemAlertType.error:
        return (Icons.error_rounded, const Color(0xFFD32F2F));
      case IpasemAlertType.loading:
        return (Icons.info_rounded, accentColor ?? brandBlue);
      case IpasemAlertType.info:
      default:
        return (Icons.info_rounded, accentColor ?? brandBlue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _styleByType(context);
    final w = MediaQuery.of(context).size.width;
    final cardWidth = math.min(w * 0.82, 380.0);

    return Material( // cobre a tela toda
      color: Colors.black38,
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 180),
          tween: Tween(begin: 0.95, end: 1),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: cardWidth,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 22,
                  color: Colors.black26,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge do cartão
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color,
                  child: Icon(icon, size: 28, color: Colors.white),
                ),

                const SizedBox(height: 16),

                // Mensagem centralizada
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.3),
                ),

                if (showProgress) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 30, height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helpers prontos para exibir/fechar como diálogo
class IpasemAlert {
  /// Mostra um dialog “toast modal” com auto-fechamento opcional.
  static Future<void> show(
      BuildContext context, {
        required String message,
        IpasemAlertType type = IpasemAlertType.info,
        Duration? autoClose,
      }) async {
    final entry = OverlayEntry(
      builder: (_) => IpasemAlertOverlay(
        message: message,
        type: type,
        showProgress: type == IpasemAlertType.loading,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    if (autoClose != null) {
      await Future.delayed(autoClose);
      entry.remove();
    }
  }

  /// Mostra um “loading modal” bloqueante (usa showGeneralDialog).
  static Future<void> showBlockingLoading(
      BuildContext context, {
        String message = 'Processando, aguarde...',
      }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'loading',
      barrierColor: Colors.black38,
      pageBuilder: (_, __, ___) => IpasemAlertOverlay(
        message: message,
        type: IpasemAlertType.loading,
        showProgress: true,
      ),
    );
  }

  /// Fecha qualquer dialog aberto via [showGeneralDialog].
  static void closeBlocking(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
