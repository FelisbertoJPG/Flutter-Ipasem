// lib/services/dev_api.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, debugPrint;
// REMOVER: import 'package:http/http.dart' as dio;

import 'redacting_log_interceptor.dart';
import '../models/dependent.dart';
import '../models/especialidade.dart';
import '../models/prestador.dart';

typedef TokenProvider = String? Function();

class DevApi {
  final String _base;            // ex.: http://192.9.200.18
  final String _apiPath;         // ex.: /api-dev.php
  String? _sessionToken;         // token em memória
  final TokenProvider? _tokenProvider;
  final bool _formUrlEncoded;    // se false, envia JSON

  String get endpoint => '$_base$_apiPath';

  static String _normalizeBase(String raw) =>
      raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;

  DevApi(
      String baseUrl, {
        String apiPath = '/api-dev.php',
        TokenProvider? tokenProvider,
        bool formUrlEncoded = true,
      })  : _base = _normalizeBase(baseUrl),
        _apiPath = apiPath,
        _tokenProvider = tokenProvider,
        _formUrlEncoded = formUrlEncoded;

  void setSessionToken(String? token) => _sessionToken = token;

  Dio _dio() {
    final d = Dio(
      BaseOptions(
        baseUrl: _base,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.json,
        headers: {
          Headers.contentTypeHeader:
          _formUrlEncoded ? Headers.formUrlEncodedContentType : Headers.jsonContentType,
        },
      ),
    );
    // logs (com redaction)
    try { d.interceptors.add(RedactingLogInterceptor()); } catch (_) {}
    // injeta X-Session
    d.interceptors.add(
      InterceptorsWrapper(onRequest: (opt, h) {
        final t = _sessionToken ?? _tokenProvider?.call();
        if (t != null && t.isNotEmpty) opt.headers['X-Session'] = t;
        h.next(opt);
      }),
    );
    if (!kReleaseMode) debugPrint('>>> DevApi base = $_base$_apiPath');
    return d;
  }

  // ====== conveniências ======
  Future<Response<T>> post<T>(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) {
    return _dio().post<T>(path, data: data, queryParameters: queryParameters, options: options);
  }

  /// Helper para rotas do api-dev.php com ?action=...
  Future<Response<T>> postAction<T>(
      String action, {
        Object? data,
        Options? options,
      }) {
    return _dio().post<T>(
      _apiPath,
      queryParameters: {'action': action},
      data: data,
      options: options,
    );
  }

  // ========== MÉTODOS ANTIGOS (restaurados) ==========

  Future<Map<String, dynamic>> login({
    required String cpf,
    required String senha,
  }) async {
    final res = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'login_repo'},
      data: {'cpf': cpf, 'senha': senha},
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
      data: {'idmatricula': idMatricula},
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

  Future<Map<String, dynamic>> ping() async {
    final r = await _dio().post(_apiPath, queryParameters: {'action': 'ping'}, data: const {});
    return (r.data as Map).cast<String, dynamic>();
  }

  /// se não existir a rota 'me' no PHP, cai no ping()
  Future<bool> checkSession() async {
    try {
      final r = await _dio().post(_apiPath, queryParameters: {'action': 'me'}, data: const {});
      final m = (r.data as Map).cast<String, dynamic>();
      return m['ok'] == true;
    } catch (_) {
      try {
        final m = await ping();
        return m['ok'] == true;
      } catch (_) {
        return false;
      }
    }
  }

  // ========== NOVOS ==========
  Future<List<Especialidade>> fetchEspecialidades() async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'especialidades'},
      data: const {},
    );
    final m = (r.data as Map).cast<String, dynamic>();
    if (m['ok'] == true) {
      final rows = (m['data']['rows'] as List?) ?? const [];
      return rows
          .map((e) => Especialidade.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
    }
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: m['error'],
    );
  }

  Future<List<String>> fetchCidadesPorEspecialidade(int especialidade) async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'cidades_por_especialidade'},
      data: {'especialidade': especialidade},
    );
    final m = (r.data as Map).cast<String, dynamic>();
    if (m['ok'] == true) {
      final rows = (m['data']['rows'] as List?) ?? const [];
      return rows.cast<String>();
    }
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: m['error'],
    );
  }

  Future<List<PrestadorRow>> fetchPrestadoresPorEspecialidade({
    required int especialidade,
    String? cidade,
  }) async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'prestadores_especialidade'},
      data: {
        'especialidade': especialidade,
        if (cidade != null && cidade.isNotEmpty) 'cidade': cidade,
      },
    );
    final m = (r.data as Map).cast<String, dynamic>();
    if (m['ok'] == true) {
      final rows = (m['data']['rows'] as List?) ?? const [];
      return rows
          .map((e) => PrestadorRow.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
    }
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: m['error'],
    );
  }
}
