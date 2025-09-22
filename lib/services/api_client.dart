// lib/services/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../config/app_config.dart';

/// Cliente HTTP centralizado do app.
/// - Baseia-se em BASE_API_URL dos AppParams (ex.: https://seu-dominio/api)
/// - Timeouts sensatos
/// - Interceptor opcional de Auth (Bearer)
class ApiClient {
  final Dio _dio;

  ApiClient._(this._dio);

  /// Constrói um ApiClient usando o contexto para ler AppConfig (BASE_API_URL).
  /// Você pode fornecer callbacks para obter/atualizar token se quiser
  /// habilitar o interceptor de autenticação.
  factory ApiClient.of(
      BuildContext context, {
        Future<String?> Function()? getAccessToken, // opcional
      }) {
    final baseUrl = AppConfig.of(context).params.baseApiUrl;
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: const {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    // Interceptor de log opcional (descomente se quiser ver requisições/respostas)
    // dio.interceptors.add(LogInterceptor(
    //   requestBody: true, responseBody: true, requestHeader: false, responseHeader: false,
    // ));

    // Interceptor de Auth (Bearer) opcional
    if (getAccessToken != null) {
      dio.interceptors.add(_AuthInterceptor(getAccessToken: getAccessToken));
    }

    return ApiClient._(dio);
  }

  /// Login no backend (POST /auth/login)
  /// Envia CPF e, se disponível, a senha. O backend decide se usa ambos ou só CPF.
  Future<Response<dynamic>> login({
    required String cpf,
    String? senha,
  }) {
    final body = <String, dynamic>{'cpf': cpf};
    if (senha != null && senha.isNotEmpty) {
      body['senha'] = senha;
    }
    return _dio.post('/auth/login', data: body);
  }

  /// Chama procedure no Postgres via backend (POST /proc/pg-run)
  /// name: ex. "public.minha_proc"
  /// args: mapa simples com parâmetros
  Future<Response<dynamic>> pgRun({
    required String name,
    Map<String, dynamic> args = const {},
    String path = '/proc/pg-run',
  }) {
    return _dio.post(path, data: {'name': name, 'args': args});
  }

  /// Chama procedure no Firebird via backend (POST /proc/fb-run)
  /// name: ex. "MINHA_PROC"
  Future<Response<dynamic>> fbRun({
    required String name,
    Map<String, dynamic> args = const {},
    String path = '/proc/fb-run',
  }) {
    return _dio.post(path, data: {'name': name, 'args': args});
  }
}

/// Interceptor simples que injeta Authorization: Bearer <token>
/// se o callback getAccessToken() retornar algo não-nulo.
/// Use quando tiver token salvo (ex.: flutter_secure_storage).
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
      // se falhar ao ler token, segue sem header
    }
    handler.next(options);
  }
}
