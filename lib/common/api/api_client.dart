//lib/common/api/api_client.dart
import 'package:dio/dio.dart';
import '../config/api_router.dart';

class ApiClient {
  final Dio dio;

  ApiClient._(this.dio);

  factory ApiClient.create() {
    final options = BaseOptions(
      baseUrl: ApiRouter.apiRootUri.toString(), // https://host/api/v1
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    return ApiClient._(Dio(options));
  }

  // GET genérico
  Future<Response<T>> get<T>(
      String path, {
        Map<String, dynamic>? query,
      }) {
    return dio.get<T>(path, queryParameters: query);
  }

  // POST genérico
  Future<Response<T>> post<T>(
      String path, {
        dynamic body,
      }) {
    return dio.post<T>(path, data: body);
  }
}
