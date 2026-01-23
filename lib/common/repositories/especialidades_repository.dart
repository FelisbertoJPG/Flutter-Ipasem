// lib/repositories/especialidades_repository.dart
import 'package:dio/dio.dart';

import '../config/dev_api.dart';
import '../models/especialidade.dart';

class EspecialidadesRepository {
  final DevApi api;
  EspecialidadesRepository(this.api);

  /// Especialidades gerais (assistência ambulatorial / médica / odonto).
  ///
  /// Backend esperado:
  ///   GET /api/v1/catalogo-assistencia/especialidades
  /// Resposta:
  /// {
  ///   "ok": true,
  ///   "data": { "rows": [ {...}, {...} ] },
  ///   "meta": ...,
  ///   "error": null
  /// }
  Future<List<Especialidade>> listar() async {
    final res = await api.get<Map<String, dynamic>>(
      '/catalogo-assistencia/especialidades',
      // mantém assinatura homogênea com outras chamadas (mesmo sem filtros)
      queryParameters: const <String, dynamic>{},
    );

    final body = res.data ?? const <String, dynamic>{};

    if (body['ok'] == true) {
      final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];

      return rows
          .whereType<Map>()
          .map((e) => Especialidade.fromMap(e.cast<String, dynamic>()))
          .toList();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'] ?? 'Falha ao carregar especialidades.',
    );
  }

  /// Especialidades específicas de EXAMES.
  ///
  /// Backend esperado:
  ///   GET /api/v1/exames/especialidades
  /// Resposta:
  /// {
  ///   "ok": true,
  ///   "data": { "rows": [ {...}, {...} ] },
  ///   "meta": ...,
  ///   "error": null
  /// }
  Future<List<Especialidade>> listarExames() async {
    final res = await api.get<Map<String, dynamic>>(
      '/exames/especialidades',
      queryParameters: const <String, dynamic>{},
    );

    final body = res.data ?? const <String, dynamic>{};

    if (body['ok'] == true) {
      final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];

      return rows
          .whereType<Map>()
          .map((e) => Especialidade.fromMap(e.cast<String, dynamic>()))
          .toList();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'] ?? 'Falha ao carregar especialidades de exames.',
    );
  }
}
