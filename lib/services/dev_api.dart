// lib/services/dev_api.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, debugPrint;

import 'redacting_log_interceptor.dart';
import '../models/dependent.dart';
import '../models/especialidade.dart';
import '../models/prestador.dart';

typedef TokenProvider = String? Function();

class DevApi {
  final String _base;            // ex.: http://192.9.200.98
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
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: {
          Headers.contentTypeHeader:
          _formUrlEncoded ? Headers.formUrlEncodedContentType : Headers.jsonContentType,
        },
      ),
    );

    // logs (com redaction)
    try {
      d.interceptors.add(RedactingLogInterceptor());
    } catch (_) {}

    // injeta X-Session e loga erros
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
            debugPrint('<<< X-EID=$eid status=${res.statusCode}');
          }
          h.next(res);
        },
        onError: (e, h) {
          // log detalhado de erro
          final eid = e.response?.headers.value('x-eid');
          debugPrint('*** HTTP ERROR *** '
              '${e.requestOptions.method} ${e.requestOptions.uri}\n'
              'status: ${e.response?.statusCode}  X-EID: ${eid ?? '-'}\n'
              'data  : ${e.response?.data}');
          h.next(e);
        },
      ),
    );

    if (!kReleaseMode) debugPrint('>>> DevApi base = $_base$_apiPath');
    return d;
  }

  // ====== helpers ======
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

  /// Upload multipart (com logs bem explícitos)
  Future<Response<dynamic>> uploadAction(
      String action, {
        required Map<String, String> fields,              // campos simples
        required List<MultipartFile> files,               // arquivos (mesmo campo 'images' repetido)
        String fileFieldName = 'images',
      }) async {
    final d = _dio();

    final form = FormData();

    // campos simples
    fields.forEach((k, v) => form.fields.add(MapEntry(k, v)));

    // arquivos (mesmo campo repetido -> PHP preenche $_FILES['images'])
    for (final f in files) {
      form.files.add(MapEntry(fileFieldName, f));
    }

    // LOG do que está indo
    if (!kReleaseMode) {
      final names = files.map((f) => f.filename).toList();
      debugPrint('>>> UPLOAD -> $_base$_apiPath?action=$action\n'
          'fields: $fields\n'
          'files : $names');
    }

    final res = await d.post(
      _apiPath,
      queryParameters: {'action': action},
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );

    if (!kReleaseMode) {
      debugPrint('<<< UPLOAD RESPONSE [${res.statusCode}] data=${res.data}');
    }

    return res;
  }

  // ========== MÉTODOS ANTIGOS/GERAIS ==========
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

  // ========= ROTAS GERAIS =========
  Future<List<Especialidade>> fetchEspecialidades() async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'especialidades'},
      data: const {},
    );
    final m = (r.data as Map).cast<String, dynamic>();
    if (m['ok'] == true) {
      final rows = (m['data']['rows'] as List?) ?? const [];
      return rows.map((e) => Especialidade.fromMap((e as Map).cast<String, dynamic>())).toList();
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
      return rows.map((e) => PrestadorRow.fromMap((e as Map).cast<String, dynamic>())).toList();
    }
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: m['error'],
    );
  }

  // ========= ROTAS EXAMES =========
  Future<List<Especialidade>> fetchEspecialidadesExames() async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'especialidades_exames'},
      data: const {},
    );
    final m = (r.data as Map).cast<String, dynamic>();
    if (m['ok'] == true) {
      final rows = (m['data']['rows'] as List?) ?? const [];
      return rows.map((e) => Especialidade.fromMap((e as Map).cast<String, dynamic>())).toList();
    }
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: m['error'],
    );
  }

  Future<List<String>> fetchCidadesPorEspecialidadeExames(int especialidade) async {
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

  Future<List<PrestadorRow>> fetchPrestadoresPorEspecialidadeExames({
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
      return rows.map((e) => PrestadorRow.fromMap((e as Map).cast<String, dynamic>())).toList();
    }
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: m['error'],
    );
  }

  // ========= ROTAS CARTEIRINHA (NOVAS) =========

  /// Emite o token da carteirinha.
  /// Importante: **não** envia nenhum campo chamado 'token' – apenas matrícula e iddependente.
  Future<Map<String, dynamic>> carteirinhaEmitir({
    required int matricula,
    String iddependente = '0',
  }) async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'carteirinha_pessoa'},
      data: {
        'matricula': matricula,
        'iddependente': iddependente,
      },
      // o backend aceita JSON ou form; mantendo o default do cliente.
    );

    final m = (r.data as Map).cast<String, dynamic>();
    if (m['ok'] == true) {
      // retorna o bloco `data` completo (string, token, db_token, expires_*, urls, etc.)
      return (m['data'] as Map).cast<String, dynamic>();
    }

    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: m['error'],
    );
  }

  /// Agenda o expurgo do token (fire-and-forget). A rota responde 202 quando tudo certo.
  Future<void> carteirinhaAgendarExpurgo({required int dbToken}) async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'carteirinha_agendar_expurgo'},
      data: {'db_token': dbToken},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    // Considera ok se 200/202; em erro, o throw abaixo garante stack com response.
    final code = r.statusCode ?? 0;
    if (code == 200 || code == 202) return;

    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: r.data,
    );
  }

  /// Valida o token (usa db_token quando disponível).
  Future<Map<String, dynamic>> carteirinhaValidar({int? dbToken, int? token}) async {
    final payload = <String, dynamic>{};
    if (dbToken != null && dbToken > 0) {
      payload['db_token'] = dbToken;
    } else if (token != null && token > 0) {
      payload['token'] = token;
    } else {
      throw ArgumentError('Informe dbToken ou token.');
    }

    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'carteirinha_validar'},
      data: payload,
    );

    final m = (r.data as Map).cast<String, dynamic>();
    if (m['ok'] == true) {
      return (m['data'] as Map).cast<String, dynamic>();
    }

    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: m['error'],
    );
  }

  /// Consulta o status do agendamento (útil para debug/telemetria no app).
  Future<Map<String, dynamic>> carteirinhaAgendarStatus({required int dbToken}) async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'carteirinha_agendar_status'},
      data: {'db_token': dbToken},
    );

    final m = (r.data as Map).cast<String, dynamic>();
    if (m['ok'] == true) {
      return (m['data'] as Map).cast<String, dynamic>();
    }

    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: m['error'],
    );
  }

  /// Retorna dados do titular + dependentes (para montar a lista no app).
  Future<Map<String, dynamic>> carteirinhaDados({required int idMatricula}) async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'carteirinha'},
      data: {'idmatricula': idMatricula},
    );

    final m = (r.data as Map).cast<String, dynamic>();
    if (m['ok'] == true) {
      return (m['data'] as Map).cast<String, dynamic>(); // {titular:{...}, dependentes:[...]}
    }

    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: m['error'],
    );
  }
}
