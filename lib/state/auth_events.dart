import 'package:flutter/foundation.dart';

/// Barramento simples de eventos entre features do app.

/// Payload para mudança de status de uma autorização de exames.
class ExameStatusChanged {
  final int numero;
  final String status; // 'A' | 'I' | 'P' | 'R'...
  const ExameStatusChanged(this.numero, this.status);
}

class AuthEvents {
  AuthEvents._();
  static final AuthEvents instance = AuthEvents._();

  /// Última autorização emitida (ao gravar/emitir).
  final ValueNotifier<int?> lastIssued = ValueNotifier<int?>(null);

  /// Última autorização que teve a PRIMEIRA impressão (A -> R).
  final ValueNotifier<int?> lastPrinted = ValueNotifier<int?>(null);

  /// Mudança de status de uma autorização (ex.: P->A, P->I, A->R…).
  final ValueNotifier<ExameStatusChanged?> exameStatusChanged =
  ValueNotifier<ExameStatusChanged?>(null);

  void emitIssued(int numero)  => lastIssued.value  = numero;
  void emitPrinted(int numero) => lastPrinted.value = numero;

  void emitStatusChanged(int numero, String status) {
    exameStatusChanged.value = ExameStatusChanged(numero, status);
  }
}
