import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, debugPrint;
// se você já usa esse interceptor, ótimo; se não, pode remover a linha.
import 'redacting_log_interceptor.dart';
import '../models/dependent.dart';

class DevApi {
  final List<String> _bases; // ex.: ['http://192.9.200.98','http://192.9.200.18','https://assistweb.ipasemnh.com.br']

  static String _normalizeBase(String raw) =>
      raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;

  DevApi(
      String baseUrl, {
        List<String>? fallbacks,
      }) : _bases = ([
    _normalizeBase(baseUrl),
    ...?fallbacks?.map(_normalizeBase),
  ].toSet()) // evita duplicadas
      .toList();

  Dio _dioFor(String base) {
    final dio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.json,
        headers: {Headers.contentTypeHeader: Headers.formUrlEncodedContentType},
      ),
    );
    // logs seguros no debug (remova se não usa)
    try {
      dio.interceptors.add(RedactingLogInterceptor());
    } catch (_) {}
    return dio;
  }

  bool _isRetryable(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    final sc = e.response?.statusCode ?? 0;
    // 5xx: tenta próximo; 4xx geralmente é erro “do pedido”, não faz fallback
    return sc >= 500 && sc <= 599;
  }

  Future<T> _withFallback<T>(
      Future<T> Function(Dio dio, String base) run,
      ) async {
    DioException? last;
    for (final base in _bases) {
      final dio = _dioFor(base);
      if (!kReleaseMode) debugPrint('>>> DevApi tentando base: $base');
      try {
        return await run(dio, base);
      } on DioException catch (e) {
        last = e;
        if (!kReleaseMode) {
          debugPrint('>>> Falhou em $base (${e.type} ${e.response?.statusCode}); ${_isRetryable(e) ? "vou tentar próximo" : "não vou repetir"}');
        }
        if (!_isRetryable(e)) rethrow; // 4xx etc: não tenta outras
        // senão, tenta próxima base
      }
    }
    // se todas falharem
    throw last ??
        DioException(
          requestOptions: RequestOptions(path: ''),
          error: 'Todas as bases falharam',
          type: DioExceptionType.unknown,
        );
  }

  // ------------ Health ------------
  Future<Map<String, dynamic>> ping() async {
    return _withFallback((dio, _) async {
      final r = await dio.get('/api-dev.php', queryParameters: {'action': 'ping'});
      return (r.data as Map).cast<String, dynamic>();
    });
  }

  Future<Map<String, dynamic>> diag() async {
    return _withFallback((dio, _) async {
      final r = await dio.get('/api-dev.php', queryParameters: {'action': 'diag'});
      return (r.data as Map).cast<String, dynamic>();
    });
  }

  // ------------ Auth ------------
  Future<Map<String, dynamic>> login({
    required String cpf,
    required String senha,
  }) async {
    return _withFallback((dio, _) async {
      final res = await dio.post(
        '/api-dev.php',
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
    });
  }

  // ------------ Dependentes ------------
  Future<List<Dependent>> fetchDependentes(int idMatricula) async {
    return _withFallback((dio, _) async {
      final res = await dio.post(
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
    });
  }
}