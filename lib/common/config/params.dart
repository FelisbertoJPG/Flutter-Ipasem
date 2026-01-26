//lib/common/config/params.dart
class AppParams {
  /// URL base da sua API (ex.: http://192.9.200.98)

  final String baseApiUrl;
  /// Validação de UX no cliente (apenas formulário).
  /// A regra real deve ser validada no servidor.
  final int passwordMinLength;
  final String firstAccessUrl; // <—

  const AppParams({
    required this.baseApiUrl,
    required this.passwordMinLength,
    required this.firstAccessUrl,
  });
  /// Lê de --dart-define (com fallback seguro).
  /// Preferimos a chave 'API_BASE' para consistência com o restante do app.
  factory AppParams.fromEnv() {
    const baseApiUrl = String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');
    const minLength  = int.fromEnvironment('PASSWORD_MIN', defaultValue: 4);
    const firstUrl   = String.fromEnvironment(
      'FIRST_ACCESS_URL',
      defaultValue: 'https://assistweb.ipasemnh.com.br/site/recuperar-senha',
    );
    return AppParams(
      baseApiUrl: baseApiUrl,
      passwordMinLength: minLength,
      firstAccessUrl: firstUrl,
    );
  }
}


