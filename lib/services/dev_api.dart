import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, debugPrint;
import '../models/dependent.dart';

class DevApi {
  final Dio _dio;

  static String _normalizeBase(String raw) =>
      raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;

  DevApi(String baseUrl)
      : _dio = Dio(
    BaseOptions(
      baseUrl: _normalizeBase(baseUrl),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      headers: {Headers.contentTypeHeader: Headers.formUrlEncodedContentType},
    ),
  ) {
    if (!kReleaseMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true, requestHeader: true, requestBody: true,
        responseHeader: false, responseBody: true, error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
      debugPrint('>>> DevApi baseUrl = ${_dio.options.baseUrl}');
    }
  }

  // --- Healthchecks úteis ---
  Future<Map<String, dynamic>> ping() async {
    final r = await _dio.get('api-dev.php', queryParameters: {'action': 'ping'});
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> diag() async {
    final r = await _dio.get('api-dev.php', queryParameters: {'action': 'diag'});
    return (r.data as Map).cast<String, dynamic>();
  }

  // --- Auth ---
  Future<Map<String, dynamic>> login({
    required String cpf,
    required String senha,
  }) async {
    final res = await _dio.post(
      '/api-dev.php', // -> preca de /
      queryParameters: {'action': 'login_repo'},
      data: {'cpf': cpf, 'senha': senha},
    );
    final body = res.data as Map<String, dynamic>;
    if (body['ok'] == true) {
      return (body['data']['profile'] as Map).cast<String, dynamic>();
    }
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'],
    );
  }

  // --- Dependentes ---
  Future<List<Dependent>> fetchDependentes(int idMatricula) async {
    final res = await _dio.post(
      '/api-dev.php',
      queryParameters: {'action': 'dependentes'},
      data: {'idmatricula': idMatricula},
    );
    final body = res.data as Map<String, dynamic>;
    if (body['ok'] == true) {
      final list = (body['data']['rows'] as List)
          .cast<Map>()
          .map((e) => Dependent.fromMap(e.cast<String, dynamic>()))
          .toList();
      return list;
    }
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'],
    );
  }
}
