// lib/services/dio_error_mapper.dart
import 'package:dio/dio.dart';
import '../core/app_exception.dart';

AppException mapDioError(DioException e) {
  // Tenta extrair uma msg amigável do backend ({"error":{"message": "..."}})
  String? backendMsg;
  final data = e.response?.data;
  if (data is Map &&
      data['error'] is Map &&
      (data['error']['message'] is String)) {
    backendMsg = data['error']['message'] as String;
  }

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutAppException();

    case DioExceptionType.badResponse:
      final code = e.response?.statusCode;
      return ApiException(backendMsg ?? 'Falha no login', statusCode: code);

    case DioExceptionType.cancel:
      return const CancelledException();

    case DioExceptionType.unknown:
    case DioExceptionType.badCertificate:
    case DioExceptionType.connectionError:
      return backendMsg != null
          ? ApiException(backendMsg)
          : const NetworkException('Não foi possível conectar ao servidor');

    default:
      return const UnexpectedException();
  }
}
