// lib/core/app_exception.dart
sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);
  @override
  String toString() => message;
}

class ApiException extends AppException {
  final int? statusCode;
  const ApiException(String msg, {this.statusCode}) : super(msg);
}

class NetworkException extends AppException {
  const NetworkException([String msg = 'Falha de rede']) : super(msg);
}

class TimeoutAppException extends AppException {
  const TimeoutAppException([String msg = 'Tempo de conexão esgotado']) : super(msg);
}

class CancelledException extends AppException {
  const CancelledException([String msg = 'Operação cancelada']) : super(msg);
}

class UnexpectedException extends AppException {
  const UnexpectedException([String msg = 'Erro inesperado']) : super(msg);
}
