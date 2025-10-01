import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

class DevApi {
  final Dio _dio;

  DevApi(String baseUrl)
      : _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        // Igual ao curl que funcionou
        Headers.contentTypeHeader: Headers.formUrlEncodedContentType,
      },
    ),
  ) {
    // LOG bem verboso (request/response/erros)
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
      logPrint: (obj) => debugPrint(obj.toString()),
    ));
    debugPrint('>>> DevApi baseUrl = ${_dio.options.baseUrl}');
  }

  Future<Map<String, dynamic>> login({
    required String cpf,
    required String senha,
  }) async {
    final res = await _dio.post(
      '/api-dev.php',
      queryParameters: {'action': 'login_repo'},
      data: {'cpf': cpf, 'senha': senha},
    );

    final body = res.data as Map<String, dynamic>;
    if (body['ok'] == true) {
      return Map<String, dynamic>.from(body['data']['profile'] as Map);
    }

    // Deixa o erro do servidor acessível
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'],
    );
  }
}
