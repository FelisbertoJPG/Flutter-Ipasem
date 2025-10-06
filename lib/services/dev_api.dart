import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, debugPrint;
import 'redacting_log_interceptor.dart';
import '../models/dependent.dart';

typedef TokenProvider = String? Function();

class DevApi {
  final String _base;      // ex.: http://192.9.200.18
  final String _apiPath;   // ex.: /api-dev.php
  String? _sessionToken;   // token em memória
  final TokenProvider? _tokenProvider;
  final bool _formUrlEncoded; // se false, envia JSON

  static String _normalizeBase(String raw) =>
      raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;

  DevApi(
      String baseUrl, {
        String apiPath = '/api-dev.php',
        TokenProvider? tokenProvider,     // <<< usa o provider
        bool formUrlEncoded = true,       // <<< toggle p/ ONLY_JSON
      })  : _base = _normalizeBase(baseUrl),
        _apiPath = apiPath,
        _tokenProvider = tokenProvider,
        _formUrlEncoded = formUrlEncoded;

  void setSessionToken(String? token) => _sessionToken = token;

  Dio _dio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _base,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.json,
        headers: {
          Headers.contentTypeHeader: _formUrlEncoded
              ? Headers.formUrlEncodedContentType
              : Headers.jsonContentType,
        },
        // Se quiser aceitar só 200:
        // validateStatus: (s) => s == 200,
      ),
    );

    // Logs com redaction
    try { dio.interceptors.add(RedactingLogInterceptor()); } catch (_) {}

    // Injeta X-Session em toda request
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opt, h) {
          final t = _sessionToken ?? _tokenProvider?.call();
          if (t != null && t.isNotEmpty) {
            opt.headers['X-Session'] = t;
          }
          h.next(opt);
        },
      ),
    );

    if (!kReleaseMode) debugPrint('>>> DevApi base = $_base$_apiPath');
    return dio;
  }

  Future<Map<String, dynamic>> login({
    required String cpf,
    required String senha,
  }) async {
    final res = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'login_repo'},
      data: _formUrlEncoded ? {'cpf': cpf, 'senha': senha} : {'cpf': cpf, 'senha': senha},
    );

    final body = res.data as Map<String, dynamic>;
    if (body['ok'] == true) {
      final data = (body['data'] as Map?) ?? const {};
      final token = data['session_token'] as String?;
      if (token != null && token.isNotEmpty) setSessionToken(token);

      final profile = (data['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
      return profile;
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
      data: _formUrlEncoded ? {'idmatricula': idMatricula} : {'idmatricula': idMatricula},
    );

    final body = res.data as Map<String, dynamic>;
    if (body['ok'] == true) {
      final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];
      return rows
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

  // Opcional: ping
  Future<Map<String, dynamic>> ping() async {
    final r = await _dio().post(_apiPath, queryParameters: {'action': 'ping'}, data: const {});
    return (r.data as Map).cast<String, dynamic>();
  }

  // Check de sessão (se você criou a rota 'me' no PHP com REQUIRE_SESSION=1)
  Future<bool> checkSession() async {
    final r = await _dio().post(_apiPath, queryParameters: {'action': 'me'}, data: const {});
    final m = (r.data as Map).cast<String, dynamic>();
    return m['ok'] == true;
  }

  // Exponho um post bruto, se precisar
  Future<Response> post(String path, {Object? data}) =>
      _dio().post(path, data: data); // <<< corrigido: _dio()
}
