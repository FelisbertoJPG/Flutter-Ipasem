// lib/services/redacting_log_interceptor.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class RedactingLogInterceptor extends Interceptor {
  final Set<String> redactKeys;

  RedactingLogInterceptor({this.redactKeys = const {'senha','password','pwd','pass','cpf'}});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kReleaseMode) return handler.next(options); // sem log em release
    final qp = Map.of(options.queryParameters);
    final data = _cloneBody(options.data);
    _redactMap(qp);
    _redactMap(data);

    debugPrint('*** Request ***');
    debugPrint('uri: ${options.uri}');
    debugPrint('method: ${options.method}');
    debugPrint('headers: ${options.headers}');
    if (qp.isNotEmpty) debugPrint('query: $qp');
    if (data != null) debugPrint('data: $data');
    handler.next(options);
  }

  @override
  void onResponse(Response res, ResponseInterceptorHandler handler) {
    if (!kReleaseMode) {
      debugPrint('*** Response *** (${res.statusCode}) ${res.requestOptions.uri}');
      // evite imprimir res.data inteiro se for grande/sensível
    }
    handler.next(res);
  }

  @override
  void onError(DioException e, ErrorInterceptorHandler handler) {
    if (!kReleaseMode) {
      debugPrint('*** DioException ***: ${e.type} url=${e.requestOptions.uri}');
      if (e.response?.data != null) debugPrint('body: <omitted>');
    }
    handler.next(e);
  }

  Map<String, dynamic>? _cloneBody(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data as Map);
    return null;
  }

  void _redactMap(Map<String, dynamic>? m) {
    if (m == null) return;
    for (final k in m.keys.toList()) {
      if (redactKeys.contains(k.toString().toLowerCase())) {
        m[k] = '***REDACTED***';
      }
    }
  }
}
