// lib/state/auth_events.dart
import 'package:flutter/foundation.dart';

class AuthEvents {
  AuthEvents._();
  static final AuthEvents instance = AuthEvents._();

  // último número emitido (null quando não há)
  final ValueNotifier<int?> lastIssued = ValueNotifier<int?>(null);

  void emitIssued(int numero) {
    lastIssued.value = numero; // ValueNotifier já notifica os listeners
  }
}
