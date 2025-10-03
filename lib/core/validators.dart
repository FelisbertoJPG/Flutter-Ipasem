// lib/core/validators.dart
library validators;

/// Retorna `null` se válido (padrão Flutter), caso contrário a mensagem de erro.
String? validateCpfDigits(String? v) {
  final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return 'Informe seu CPF';
  if (d.length != 11) return 'CPF deve ter 11 dígitos';
  return null;
}

String? validatePassword(String? v, {required int minLen}) {
  final s = v ?? '';
  if (s.isEmpty) return 'Informe sua senha';
  if (s.length < minLen) return 'Senha muito curta (mínimo: $minLen)';
  return null;
}
