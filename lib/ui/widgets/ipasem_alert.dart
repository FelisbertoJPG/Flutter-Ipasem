import 'dart:math' as math;
import 'package:flutter/material.dart';

enum IpasemAlertType { info, success, warning, error, loading }

/// Variante da badge:
/// - printLike: círculo sólido + letra (ex.: "i"), igual ao print
/// - materialIcon: usa o ícone do Material (info_rounded, warning, etc.)
enum IpasemBadgeVariant { printLike, materialIcon }

class IpasemAlertOverlay extends StatelessWidget {
  final String message;
  final IpasemAlertType type;
  final Color? accentColor;
  final bool showProgress;

  /// Escolha da badge (default = printLike para bater com o print)
  final IpasemBadgeVariant badgeVariant;

  /// Tamanho da bolinha/ícone
  final double badgeRadius;
  final double badgeIconSize;

  const IpasemAlertOverlay({
    super.key,
    required this.message,
    this.type = IpasemAlertType.info,
    this.accentColor,
    this.showProgress = false,
    this.badgeVariant = IpasemBadgeVariant.printLike,
    this.badgeRadius = 28,
    this.badgeIconSize = 28,
  });

  (IconData, Color) _styleByType() {
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

  /// Letra mostrada no modo printLike (para o “i” ficar sem círculo do ícone)
  String _glyphByType() {
    switch (type) {
      case IpasemAlertType.success:
        return '✓';
      case IpasemAlertType.warning:
        return '!';
      case IpasemAlertType.error:
        return '!';
      case IpasemAlertType.loading:
      case IpasemAlertType.info:
      default:
        return 'i';
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _styleByType();
    final w = MediaQuery.of(context).size.width;
    final cardWidth = math.min(w * 0.82, 380.0);

    return Material(
      color: Colors.black38, // backdrop
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 180),
          tween: Tween(begin: 0.95, end: 1),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: cardWidth,
            padding: const EdgeInsets.all(20),
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
                /// ===== BADGE (dentro do cartão) =====
                if (badgeVariant == IpasemBadgeVariant.printLike)
                  Container(
                    width: badgeRadius * 2,
                    height: badgeRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _glyphByType(),
                      /// “i” igual ao print: fonte pesada e sem espaçamento
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: badgeIconSize,
                        height: 1.0, // evita “pular” vertical
                        letterSpacing: 0,
                      ),
                    ),
                  )
                else
                  CircleAvatar(
                    radius: badgeRadius,
                    backgroundColor: color,
                    child: Icon(icon, size: badgeIconSize, color: Colors.white),
                  ),

                const SizedBox(height: 16),

                // Mensagem
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.3),
                ),

                if (showProgress) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 30,
                    height: 30,
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

/// Helpers para exibir/fechar rapidamente
class IpasemAlert {
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
        // garante que use o estilo do print por padrão:
        badgeVariant: IpasemBadgeVariant.printLike,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    if (autoClose != null) {
      await Future.delayed(autoClose);
      entry.remove();
    }
  }

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
        badgeVariant: IpasemBadgeVariant.printLike,
      ),
    );
  }

  static void closeBlocking(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
