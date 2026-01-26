// lib/repositories/dependents_repository.dart
import 'package:dio/dio.dart';

import '../config/dev_api.dart';
import '../models/dependent.dart';

class DependentsRepository {
  final DevApi api;
  DependentsRepository(this.api);

  /// Lista dependentes de um titular pela matrícula.
  ///
  /// Backend: POST /api/v1/titular/dependentes
  /// Resposta esperada:
  /// {
  ///   "ok": true,
  ///   "data": {
  ///     "rows": [ {...}, {...} ]
  ///   },
  ///   "meta": ...,
  ///   "error": null
  /// }
  Future<List<Dependent>> listByMatricula(int idMatricula) async {
    final res = await api.post<Map<String, dynamic>>(
      '/titular/dependentes',
      data: {'idmatricula': idMatricula},
    );

    final body = res.data ?? const <String, dynamic>{};

    if (body['ok'] == true) {
      final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];
      return rows
          .whereType<Map>()
          .map((e) => Dependent.fromMap(e.cast<String, dynamic>()))
          .toList();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'] ?? 'Falha ao buscar dependentes.',
    );
  }
}
