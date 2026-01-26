// lib/common/config/dev_api.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, debugPrint;

import 'api_router.dart';
import '../services/redacting_log_interceptor.dart';

typedef TokenProvider = String? Function();

/// Client HTTP básico para a API REST (/api/v1).
///
/// - Usa sempre `ApiRouter.apiRootUri` como base (https://host/api/v1).
/// - Injeta, se existir, o header `X-Session` com o token de sessão.
/// - Faz logging redigido via `RedactingLogInterceptor`.
class DevApi {
  String? _sessionToken;          // token em memória (opcional)
  final TokenProvider? _tokenProvider;
  final bool _formUrlEncoded;     // se false, envia JSON

  DevApi({
    TokenProvider? tokenProvider,
    bool formUrlEncoded = true, // para JSON "puro", instancie com false
  })  : _tokenProvider = tokenProvider,
        _formUrlEncoded = formUrlEncoded;

  void setSessionToken(String? token) => _sessionToken = token;

  Dio _dio() {
    // Base sempre vem do ApiRouter: ex.: https://assistweb.ipasemnh.com.br/api/v1
    final baseUrl = ApiRouter.apiRootUri.toString();

    final d = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: {
          Headers.contentTypeHeader: _formUrlEncoded
              ? Headers.formUrlEncodedContentType
              : Headers.jsonContentType,
        },
      ),
    );

    // Log redigido das requisições
    try {
      d.interceptors.add(RedactingLogInterceptor());
    } catch (_) {}

    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opt, h) {
          final t = _sessionToken ?? _tokenProvider?.call();
          if (t != null && t.isNotEmpty) {
            opt.headers['X-Session'] = t;
          }
          h.next(opt);
        },
        onResponse: (res, h) {
          final eid = res.headers.value('x-eid');
          if (!kReleaseMode && eid != null) {
            debugPrint('<<< X-EID=$eid status=${res.statusCode}');
          }
          h.next(res);
        },
        onError: (e, h) {
          final eid = e.response?.headers.value('x-eid');
          debugPrint(
            '*** HTTP ERROR *** '
                '${e.requestOptions.method} ${e.requestOptions.uri}\n'
                'status: ${e.response?.statusCode}  X-EID: ${eid ?? '-'}\n'
                'data  : ${e.response?.data}\n'
                'raw   : ${e.error}', // <<< adiciona isso temporariamente
          );
          h.next(e);
        },
      ),
    );

    if (!kReleaseMode) {
      debugPrint('>>> DevApi baseUrl = $baseUrl');
    }

    return d;
  }

  String _normalizePath(String path) =>
      path.startsWith('/') ? path : '/$path';

  // ===========================================================================
  // REST genérico (/api/v1)
  // ===========================================================================

  Future<Response<T>> get<T>(
      String path, {
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) {
    final p = _normalizePath(path);
    return _dio().get<T>(
      p,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) {
    final p = _normalizePath(path);
    return _dio().post<T>(
      p,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // Aliases para manter compatibilidade com nomes antigos (`getRest`/`postRest`)

  Future<Response<T>> getRest<T>(
      String path, {
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) =>
      get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );

  Future<Response<T>> postRest<T>(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) =>
      post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
}
