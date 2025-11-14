// lib/state/notification_bridge.dart
import 'package:flutter/foundation.dart'; // kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint
import '../services/notifier.dart';
import 'auth_events.dart';

/// Faz a ponte entre eventos de autorização (AuthEvents) e notificações locais
/// (AppNotifier). Em plataformas sem suporte (Web/desktop), vira NO-OP seguro.
///
/// Use: chame `NotificationBridge.I.attach()` UMA vez na inicialização do app.
class NotificationBridge {
  NotificationBridge._();
  static final NotificationBridge I = NotificationBridge._();

  bool _attached = false;

  VoidCallback? _issuedL;
  VoidCallback? _printedL;
  VoidCallback? _statusL;

  bool get _supportsLocalNotifications {
    if (kIsWeb) return false;
    // Ajuste se você suportar mais plataformas no AppNotifier
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> attach() async {
    if (_attached) return;

    // Sem suporte? Apenas marca como anexado e sai (não registra listeners).
    if (!_supportsLocalNotifications) {
      _attached = true;
      debugPrint('NotificationBridge: no-op (platform not supported).');
      return;
    }

    // Inicializa o AppNotifier com proteção contra falhas.
    try {
      await AppNotifier.I.init(); // canais/permissões (Android/iOS)
    } catch (e, st) {
      debugPrint('NotificationBridge: AppNotifier.init() falhou. '
          'Seguindo sem notificações. $e\n$st');
      _attached = true; // evita tentar de novo e travar bootstrap
      return;
    }

    // Listeners protegidos — só chegam aqui se init() ok.
    _issuedL = () {
      final n = AuthEvents.instance.lastIssued.value;
      if (n != null) {
        AppNotifier.I.showSimple(
          title: 'Autorização enviada',
          body: '',
        );
      }
    };

    _printedL = () {
      final n = AuthEvents.instance.lastPrinted.value;
      if (n != null) {
        // notifica ao imprimir pela 1ª vez (A -> R), se desejado
        AppNotifier.I.notifyExameLiberado(numero: n);
      }
    };

    _statusL = () {
      final evt = AuthEvents.instance.exameStatusChanged.value;
      if (evt == null) return;
      if (evt.status == 'A') {
        AppNotifier.I.notifyExameLiberado(numero: evt.numero);
      } else if (evt.status == 'I') {
        AppNotifier.I.showSimple(
          title: 'Autorização negada',
          body: 'A autorização #${evt.numero} foi negada.',
        );
      } // outros status: ignora
    };

    AuthEvents.instance.lastIssued.addListener(_issuedL!);
    AuthEvents.instance.lastPrinted.addListener(_printedL!);
    AuthEvents.instance.exameStatusChanged.addListener(_statusL!);

    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    if (_issuedL != null) {
      AuthEvents.instance.lastIssued.removeListener(_issuedL!);
    }
    if (_printedL != null) {
      AuthEvents.instance.lastPrinted.removeListener(_printedL!);
    }
    if (_statusL != null) {
      AuthEvents.instance.exameStatusChanged.removeListener(_statusL!);
    }
    _issuedL = null;
    _printedL = null;
    _statusL = null;
    _attached = false;
  }
}
