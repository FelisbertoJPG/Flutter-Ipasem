// lib/state/notification_bridge.dart
import 'package:flutter/foundation.dart';
import '../services/notifier.dart';
import 'auth_events.dart';

/// Escuta AuthEvents e dispara AppNotifier. Anexe 1x no app.
class NotificationBridge {
  NotificationBridge._();
  static final NotificationBridge I = NotificationBridge._();

  bool _attached = false;
  VoidCallback? _issuedL;
  VoidCallback? _printedL;

  Future<void> attach() async {
    if (_attached) return;
    await AppNotifier.I.init(); // garante canal e permissão

    _issuedL = () {
      final n = AuthEvents.instance.lastIssued.value;
      if (n != null) {
        AppNotifier.I.showSimple(
          title: 'Autorização enviada',
          body: 'Vamos avisar quando for liberada.',
        );
      }
    };

    _printedL = () {
      final n = AuthEvents.instance.lastPrinted.value;
      if (n != null) {
        AppNotifier.I.notifyExameLiberado(numero: n);
      }
    };

    AuthEvents.instance.lastIssued.addListener(_issuedL!);
    AuthEvents.instance.lastPrinted.addListener(_printedL!);
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
    _attached = false;
  }
}
