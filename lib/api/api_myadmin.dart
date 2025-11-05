import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, debugPrint;
import '../services/redacting_log_interceptor.dart';

class ApiMyAdmin {
  final String _base;
  final String _apiPath;
  String? _sessionToken;
  final String? Function()? _tokenProvider;
  final bool _formUrlEncoded;

  static String _normalizeBase(String raw) =>
      raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;

  ApiMyAdmin(
      String baseUrl, {
        String apiPath = '/api-dev.php',
        String? Function()? tokenProvider,
        bool formUrlEncoded = true,
      })  : _base = _normalizeBase(baseUrl),
        _apiPath = apiPath,
        _tokenProvider = tokenProvider,
        _formUrlEncoded = formUrlEncoded;

  String get endpoint => '$_base$_apiPath';
  void setSessionToken(String? token) => _sessionToken = token;

  Dio _dio() {
    final d = Dio(
      BaseOptions(
        baseUrl: _base,
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

    try {
      d.interceptors.add(RedactingLogInterceptor());
    } catch (_) {}

    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opt, h) {
          final t = _sessionToken ?? _tokenProvider?.call();
          if (t != null && t.isNotEmpty) opt.headers['X-Session'] = t;
          h.next(opt);
        },
        onResponse: (res, h) {
          final eid = res.headers.value('x-eid');
          if (!kReleaseMode && eid != null) {
            debugPrint('<<< [ApiMyAdmin] X-EID=$eid status=${res.statusCode}');
          }
          h.next(res);
        },
        onError: (e, h) {
          final eid = e.response?.headers.value('x-eid');
          debugPrint('*** HTTP ERROR (ApiMyAdmin) *** '
              '${e.requestOptions.method} ${e.requestOptions.uri}\n'
              'status: ${e.response?.statusCode}  X-EID: ${eid ?? '-'}\n'
              'data  : ${e.response?.data}');
          h.next(e);
        },
      ),
    );

    if (!kReleaseMode) debugPrint('>>> ApiMyAdmin base = $_base$_apiPath');
    return d;
  }

  Future<Response<T>> _postAction<T>(
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

  // ===== Básico
  Future<Map<String, dynamic>> ping() async {
    final r = await _postAction<Map<String, dynamic>>('ping', data: const {});
    return (r.data ?? const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> diag() async {
    final r = await _postAction<Map<String, dynamic>>('diag', data: const {});
    return (r.data ?? const <String, dynamic>{});
  }

  // ===== Comunicados
  Future<List<Comunicado>> listarComunicados({
    int limit = 20,
    int offset = 0,
    String? categoria,
    String? q,
  }) async {
    final payload = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (categoria != null && categoria.isNotEmpty) 'categoria': categoria,
      if (q != null && q.isNotEmpty) 'q': q,
    };

    final res =
    await _postAction<Map<String, dynamic>>('comunicados', data: payload);
    final body = (res.data ?? const <String, dynamic>{});
    if (body['ok'] == true) {
      final data = (body['data'] as Map?) ?? const {};
      final rows = (data['rows'] as List?) ?? const [];
      return rows
          .cast<Map>()
          .map((e) => Comunicado.fromMap(e.cast<String, dynamic>()))
          .toList();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'],
    );
  }

  Future<Comunicado> obterComunicado(int id) async {
    final res =
    await _postAction<Map<String, dynamic>>('comunicado', data: {'id': id});
    final body = (res.data ?? const <String, dynamic>{});
    if (body['ok'] == true) {
      final data = (body['data'] as Map?) ?? const {};
      final item = (data['item'] as Map?)?.cast<String, dynamic>();
      if (item == null) {
        throw StateError('Resposta sem item.');
      }
      return Comunicado.fromMap(item);
    }

    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'],
    );
  }
}

class Comunicado {
  final int id;
  final String titulo;
  final String corpo;
  final String? resumo;
  final String? categoria;
  final String? tags;
  final int ordem;
  final DateTime? publicadoEm;
  final DateTime? expiraEm;

  Comunicado({
    required this.id,
    required this.titulo,
    required this.corpo,
    required this.ordem,
    this.resumo,
    this.categoria,
    this.tags,
    this.publicadoEm,
    this.expiraEm,
  });

  factory Comunicado.fromMap(Map<String, dynamic> m) {
    DateTime? _parseDate(String? iso) {
      if (iso == null || iso.isEmpty) return null;
      final d = DateTime.tryParse(iso);
      return d?.toLocal(); // <-- garante horário local
    }

    return Comunicado(
      id: (m['id'] ?? 0) as int,
      titulo: (m['titulo'] ?? '') as String,
      corpo: (m['corpo'] ?? '') as String,
      resumo: m['resumo'] as String?,
      categoria: m['categoria'] as String?,
      tags: m['tags'] as String?,
      ordem: (m['ordem'] ?? 0) as int,
      publicadoEm: _parseDate(m['publicadoEm'] as String?),
      expiraEm: _parseDate(m['expiraEm'] as String?),
    );
  }
}
