// lib/navigation/safe_back.dart
import 'package:flutter/material.dart';

/// Intercepta o "voltar".
/// - Se houver algo na pilha, dá pop normalmente.
/// - Se NÃO houver, navega para [fallbackRoute] por pushReplacementNamed().
/// Retorna sempre false para impedir o pop padrão do Navigator.
Future<bool> handleBackWithFallback(
    BuildContext context, {
      String fallbackRoute = '/servicos',
    }) async {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
  } else {
    // garante que o app não "feche", nem retorne para uma rota de splash/login
    nav.pushReplacementNamed(fallbackRoute);
  }
  return false;
}
