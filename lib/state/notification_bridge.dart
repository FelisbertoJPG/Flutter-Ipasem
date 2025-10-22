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
  VoidCallback? _statusL; // <- novo

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
        // se quiser notificar ao imprimir pela 1ª vez
        AppNotifier.I.notifyExameLiberado(numero: n);
      }
    };

    _statusL = () {
      final evt = AuthEvents.instance.exameStatusChanged.value;
      if (evt == null) return;
      if (evt.status == 'A') {
        // liberada
        AppNotifier.I.notifyExameLiberado(numero: evt.numero);
      } else if (evt.status == 'I') {
        // negada
        AppNotifier.I.showSimple(
          title: 'Autorização negada',
          body: 'A autorização #${evt.numero} foi negada.',
        );
      } // outros status: ignore
    };

    AuthEvents.instance.lastIssued.addListener(_issuedL!);
    AuthEvents.instance.lastPrinted.addListener(_printedL!);
    AuthEvents.instance.exameStatusChanged.addListener(_statusL!); // <- novo

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
    _attached = false;
  }
}
