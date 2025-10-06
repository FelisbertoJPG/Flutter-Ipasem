import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, debugPrint;
import 'redacting_log_interceptor.dart';
import '../models/dependent.dart';

class DevApi {
  final String _base;      // ex.: http://192.9.200.18
  final String _apiPath;   // ex.: /api-dev.php
  String? _sessionToken;   // opcional

  static String _normalizeBase(String raw) =>
      raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;

  DevApi(String baseUrl, { String apiPath = '/api-dev.php' })
      : _base = _normalizeBase(baseUrl),
        _apiPath = apiPath;

  void setSessionToken(String? token) => _sessionToken = token;

  Dio _dio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _base,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.json,
        // compat com seu PHP atual (form-url-encoded)
        headers: { Headers.contentTypeHeader: Headers.formUrlEncodedContentType },
      ),
    );
    try { dio.interceptors.add(RedactingLogInterceptor()); } catch (_) {}
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: (opt, h) {
        final t = _sessionToken;
        if (t != null && t.isNotEmpty) opt.headers['X-Session'] = t;
        h.next(opt);
      }),
    );
    if (!kReleaseMode) debugPrint('>>> DevApi base = $_base$_apiPath');
    return dio;
  }

  Future<Map<String, dynamic>> login({required String cpf, required String senha}) async {
    final res = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'login_repo'},
      data: {'cpf': cpf, 'senha': senha},
    );
    final body = res.data as Map<String, dynamic>;
    if (body['ok'] == true) {
      final token = (body['data'] as Map?)?['session_token'] as String?;
      if (token != null && token.isNotEmpty) setSessionToken(token);
      return (body['data']['profile'] as Map).cast<String, dynamic>();
    }
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'],
    );
  }

  Future<List<Dependent>> fetchDependentes(int idMatricula) async {
    final res = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'dependentes'},
      data: {'idmatricula': idMatricula},
    );
    final body = res.data as Map<String, dynamic>;
    if (body['ok'] == true) {
      return (body['data']['rows'] as List)
          .cast<Map>()
          .map((e) => Dependent.fromMap(e.cast<String, dynamic>()))
          .toList();
    }
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'],
    );
  }

  // (opcionais)
  Future<Map<String, dynamic>> ping() async {
    final r = await _dio().post(_apiPath, queryParameters: {'action': 'ping'}, data: const {});
    return (r.data as Map).cast<String, dynamic>();
  }
}
