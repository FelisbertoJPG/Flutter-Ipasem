import 'package:flutter/foundation.dart';

/// Barramento simples de eventos entre features da app.
class AuthEvents {
  AuthEvents._();
  static final AuthEvents instance = AuthEvents._();

  /// Última autorização emitida (Acontece ao gravar/emitir).
  final ValueNotifier<int?> lastIssued = ValueNotifier<int?>(null);

  /// Última autorização que teve a PRIMEIRA impressão (A -> R).
  final ValueNotifier<int?> lastPrinted = ValueNotifier<int?>(null);

  void emitIssued(int numero)  => lastIssued.value  = numero;
  void emitPrinted(int numero) => lastPrinted.value = numero;
}
