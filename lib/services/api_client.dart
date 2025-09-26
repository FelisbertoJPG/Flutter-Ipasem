// lib/services/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../config/app_config.dart';

class ApiClient {
  final Dio _dio;

  ApiClient._(this._dio);

  factory ApiClient.of(
      BuildContext context, {
        Future<String?> Function()? getAccessToken, // opcional
      }) {
    // Espera BASE_API_URL = http://192.9.200.98/admin/api (sem / no final)
    final raw = AppConfig.of(context).params.baseApiUrl.trim();
    final baseUrl = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        // Deixa o Dio lançar exceção em 4xx/5xx (padrão). Se quiser
        // receber Response mesmo com erro, descomente:
        // validateStatus: (_) => true,
      ),
    );

    // Logs (útil em HML)
    // dio.interceptors.add(LogInterceptor(
    //   requestBody: true, responseBody: true, requestHeader: false, responseHeader: false,
    // ));

    if (getAccessToken != null) {
      dio.interceptors.add(_AuthInterceptor(getAccessToken: getAccessToken));
    }

    return ApiClient._(dio);
  }

  /// POST genérico com parse e tratamento de erro
  Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    try {
      final res = await _dio.post(path, data: data);
      return res.data; // Dio já faz decode do JSON
    } on DioException catch (e) {
      // Tenta extrair mensagem amigável do backend
      final msg = e.response?.data is Map
          ? (e.response!.data['error'] ??
          e.response!.data['message'] ??
          'Erro HTTP ${e.response!.statusCode}')
          : (e.message ?? 'Falha de rede');
      throw Exception(msg);
    }
  }

  /// GET simples (se precisar)
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return res.data;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['error'] ??
          e.response!.data['message'] ??
          'Erro HTTP ${e.response!.statusCode}')
          : (e.message ?? 'Falha de rede');
      throw Exception(msg);
    }
  }

  /// Ping (opcional)
  Future<dynamic> ping() => get('/ping');

  /// Login -> POST /auth/login
  Future<dynamic> login({
    required String cpf,
    required String senha,
  }) {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    return _post('/auth/login', {'cpf': digits, 'senha': senha});
  }

  /// Postgres: POST /proc/pg-run
  Future<dynamic> pgRun({
    required String name,
    Map<String, dynamic> args = const {},
    String path = '/proc/pg-run',
  }) {
    return _post(path, {'name': name, 'args': args});
  }

  /// Firebird: POST /proc/fb-run
  Future<dynamic> fbRun({
    required String name,
    Map<String, dynamic> args = const {},
    String path = '/proc/fb-run',
  }) {
    return _post(path, {'name': name, 'args': args});
  }
}

class _AuthInterceptor extends Interceptor {
  final Future<String?> Function() getAccessToken;
  _AuthInterceptor({required this.getAccessToken});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // segue sem header
    }
    handler.next(options);
  }
}
