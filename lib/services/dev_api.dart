import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, debugPrint;

import '../models/dependent.dart';

// Import opcional: só será usado se você fornecer bridgeUrl/apiKey/secret.
// Se você ainda não criou o helper, tudo bem: mantenha esse import.
// Crie depois em lib/core/bridge_client.dart com o postSigned(...) que combinamos.
import '../core/bridge_client.dart';

class DevApi {
  final Dio _dio;

  // Bridge (opcional)
  final Uri? _bridgeUrl;     // ex.: http://192.9.200.98/bridge-api-dev
  final String? _apiKey;
  final String? _apiSecret;

  static String _normalizeBase(String raw) =>
      raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;

  bool get _useBridge =>
      _bridgeUrl != null && _apiKey != null && _apiSecret != null;

  /// === Construtor RETROCOMPATÍVEL ===
  /// Continua aceitando só `baseUrl`, como antes.
  DevApi(
      String baseUrl, {
        String? bridgeUrl,
        String? apiKey,
        String? apiSecret,
      })  : _dio = Dio(
    BaseOptions(
      baseUrl: _normalizeBase(baseUrl),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      // mantém comportamento antigo por padrão
      headers: {Headers.contentTypeHeader: Headers.formUrlEncodedContentType},
    ),
  ),
        _bridgeUrl = bridgeUrl != null ? Uri.parse(bridgeUrl) : null,
        _apiKey = apiKey,
        _apiSecret = apiSecret {
    if (!kReleaseMode) {
      debugPrint('>>> DevApi baseUrl   = ${_dio.options.baseUrl}');
      debugPrint('>>> DevApi useBridge = $_useBridge');
      if (_useBridge) debugPrint('>>> DevApi bridgeUrl = $_bridgeUrl');
    }
  }

  // =================== Helpers ===================

  Future<Map<String, dynamic>> _bridgeCall(
      String action,
      Map<String, dynamic> body,
      ) async {
    if (!_useBridge) {
      throw StateError('Bridge não configurado');
    }
    final url = _bridgeUrl!.replace(queryParameters: {'action': action});
    final res = await postSigned(
      dio: _dio,
      url: url,
      apiKey: _apiKey!,
      secret: _apiSecret!,
      body: body,
    );
    final data = (res.data as Map).cast<String, dynamic>();
    if (data['ok'] == true) return (data['data'] as Map).cast<String, dynamic>();
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: data['error'],
    );
  }

  Future<Map<String, dynamic>> _directCall(
      String action,
      Map<String, dynamic> formBody,
      ) async {
    // Mantém o caminho antigo: /api-dev.php?action=...
    final res = await _dio.post(
      '/api-dev.php',
      queryParameters: {'action': action},
      data: formBody,
      options: Options(
        contentType: Headers.formUrlEncodedContentType, // igual ao antigo
      ),
    );
    final data = (res.data as Map).cast<String, dynamic>();
    if (data['ok'] == true) return (data['data'] as Map).cast<String, dynamic>();
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: data['error'],
    );
  }

  Future<Map<String, dynamic>> _call(
      String action, {
        Map<String, dynamic> formBody = const {},
      }) {
    // Se bridge estiver configurado, usa bridge; senão, usa o fluxo antigo.
    return _useBridge ? _bridgeCall(action, formBody) : _directCall(action, formBody);
  }

  // =================== Endpoints ===================

  // Health
  Future<Map<String, dynamic>> ping() async {
    // No modo direto antigo o ping era GET; aqui padronizei em POST,
    // mas o PHP aceita ambos se você quiser manter GET, é só criar _directGet.
    return _call('ping');
  }

  Future<Map<String, dynamic>> diag() async {
    return _call('diag');
  }

  // Auth
  Future<Map<String, dynamic>> login({
    required String cpf,
    required String senha,
  }) async {
    final out = await _call('login_repo', formBody: {'cpf': cpf, 'senha': senha});
    return (out['profile'] as Map).cast<String, dynamic>();
  }

  // Dependentes
  Future<List<Dependent>> fetchDependentes(int idMatricula) async {
    final out = await _call('dependentes', formBody: {'idmatricula': idMatricula});
    final list = (out['rows'] as List)
        .cast<Map>()
        .map((e) => Dependent.fromMap(e.cast<String, dynamic>()))
        .toList();
    return list;
  }
}
