// lib/config/params.dart
class AppParams {
  /// URL base da sua API (ex.: http://192.9.200.98)
  final String baseApiUrl;

  /// Validação de UX no cliente (apenas formulário).
  /// A regra real deve ser validada no servidor.
  final int passwordMinLength;

  const AppParams({
    required this.baseApiUrl,
    this.passwordMinLength = 4,
  });

  /// Lê de --dart-define (com fallback seguro).
  /// Preferimos a chave 'API_BASE' para consistência com o restante do app.
  factory AppParams.fromEnv() {
    // Compat: lê API_BASE; se não vier, tenta BASE_API_URL
    const base = String.fromEnvironment(
      'API_BASE',
      defaultValue: String.fromEnvironment(
        'BASE_API_URL',
        defaultValue: 'http://192.9.200.98', // ajuste seu default local
      ),
    );

    const minPwd = int.fromEnvironment('PASSWORD_MIN', defaultValue: 4);

    return AppParams(
      baseApiUrl: base,
      passwordMinLength: minPwd,
    );
  }
}
