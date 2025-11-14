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
            debugPrint('<<< X-EID=$eid status=${res.statusCode}');
          }
          h.next(res);
        },
        onError: (e, h) {
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

  Future<Response<dynamic>> uploadAction(
      String action, {
        required Map<String, String> fields,
        required List<MultipartFile> files,
        String fileFieldName = 'images',
      }) async {
    final d = _dio();
    final form = FormData();

    fields.forEach((k, v) => form.fields.add(MapEntry(k, v)));
    for (final f in files) {
      form.files.add(MapEntry(fileFieldName, f));
    }

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
      // FIX: nada de cascade aqui; só faça trim no valor retornado.
      final rawToken = (data['session_token'] as String?)?.trim();
      if (rawToken != null && rawToken.isNotEmpty) {
        setSessionToken(rawToken);
      }
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

  // ========= ROTAS CARTEIRINHA =========

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

  Future<Map<String, dynamic>> carteirinhaConsultarAtivo({
    required int matricula,
    String iddependente = '0',
  }) async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'carteirinha_consultar_ativo'},
      data: {
        'matricula': matricula,
        'iddependente': iddependente,
      },
    );

    final m = (r.data as Map).cast<String, dynamic>();
    if (m['ok'] == true) {
      final data = m['data'];
      if (data is Map) return (data as Map).cast<String, dynamic>();
      return const <String, dynamic>{};
    }

    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: m['error'],
    );
  }

  Future<void> carteirinhaAgendarExpurgo({required int dbToken}) async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'carteirinha_agendar_expurgo'},
      data: {'db_token': dbToken},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final code = r.statusCode ?? 0;
    if (code == 200 || code == 202) return;

    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: r.data,
    );
  }

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

  Future<Map<String, dynamic>> carteirinhaDados({required int idMatricula}) async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'carteirinha'},
      data: {'idmatricula': idMatricula},
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

  Future<void> carteirinhaExcluir({required int dbToken}) async {
    final r = await _dio().post(
      _apiPath,
      queryParameters: {'action': 'carteirinha_excluir_token'},
      data: {'db_token': dbToken},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final code = r.statusCode ?? 0;
    if (code == 200) return;

    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
      error: r.data,
    );
  }

}
