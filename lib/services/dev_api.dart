// lib/api/dev_api.dart
import 'package:dio/dio.dart';

class DevApi {
  final Dio _dio;

  DevApi(String baseUrl)
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl, // ex.: 'http://192.9.200.98'
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      // nosso endpoint aceita x-www-form-urlencoded tranquilamente
      Headers.contentTypeHeader: Headers.formUrlEncodedContentType,
    },
  ));

  /// POST /api-dev.php?action=login_repo
  // lib/api/dev_api.dart
  Future<Map<String, dynamic>> login(
      {required String cpf, required String senha}) async {
    final res = await _dio.post(
      '/api-dev.php',
      queryParameters: {'action': 'login_repo'},
      data: {'cpf': cpf, 'senha': senha},
    );

    final body = res.data as Map<String, dynamic>;
    if (body['ok'] == true) {
      return Map<String, dynamic>.from(body['data']['profile'] as Map);
    }

    // monta uma DioException “completa” (sem setar campos finais)
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'], // mantém o JSON do erro aqui
    );
  }
}
