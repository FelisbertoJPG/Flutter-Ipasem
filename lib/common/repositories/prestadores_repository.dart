// lib/repositories/prestadores_repository.dart
import 'package:dio/dio.dart';

import '../config/dev_api.dart';
import '../models/prestador.dart';

class PrestadoresRepository {
  final DevApi api;
  PrestadoresRepository(this.api);

  // ------------------------ Helpers internos ------------------------

  Map<String, dynamic> _expectOkEnvelope(Response res) {
    final data = res.data;
    if (data is! Map) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: 'Resposta inválida (não é JSON objeto).',
      );
    }

    final body = data.cast<String, dynamic>();
    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: body['error'] ?? body,
      );
    }

    return body;
  }

  List<Map<String, dynamic>> _extractRows(Map<String, dynamic> body) {
    final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList(growable: false);
  }

  // ------------------------ Assistência (consultas gerais) ------------------------

  /// Lista cidades disponíveis para uma especialidade (assistência).
  ///
  /// GET /api/v1/catalogo-assistencia/cidades-por-especialidade?especialidade=ID
  Future<List<String>> cidadesDisponiveis(int especialidade) async {
    final res = await api.get<dynamic>(
      '/catalogo-assistencia/cidades-por-especialidade',
      queryParameters: {'especialidade': especialidade},
    );

    final body = _expectOkEnvelope(res);
    final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];

    // No gateway antigo já vinha como lista de strings; aqui mantemos a ideia.
    return rows.map((e) => e.toString()).toList(growable: false);
  }

  /// Lista prestadores por especialidade (e cidade opcional) em assistência.
  ///
  /// GET /api/v1/catalogo-assistencia/prestadores-especialidade
  ///      ?especialidade=ID&cidade=XXX
  Future<List<PrestadorRow>> porEspecialidade(
      int especialidade, {
        String? cidade,
      }) async {
    final res = await api.get<dynamic>(
      '/catalogo-assistencia/prestadores-especialidade',
      queryParameters: {
        'especialidade': especialidade,
        if (cidade != null && cidade.isNotEmpty) 'cidade': cidade,
      },
    );

    final body = _expectOkEnvelope(res);
    final rows = _extractRows(body);

    return rows
        .map((r) => PrestadorRow.fromJson(r))
        .toList(growable: false);
  }

  // ------------------------ Exames ------------------------

  /// Cidades para uma especialidade de EXAMES.
  ///
  /// GET /api/v1/exames/cidades-por-especialidade?especialidade=ID
  Future<List<String>> cidadesDisponiveisExames(int especialidade) async {
    final res = await api.get<dynamic>(
      '/exames/cidades-por-especialidade',
      queryParameters: {'especialidade': especialidade},
    );

    final body = _expectOkEnvelope(res);
    final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];

    return rows.map((e) => e.toString()).toList(growable: false);
  }

  /// Prestadores de EXAMES por especialidade (e cidade opcional).
  ///
  /// GET /api/v1/exames/prestadores-especialidade
  ///      ?especialidade=ID&cidade=XXX
  Future<List<PrestadorRow>> porEspecialidadeExames(
      int especialidade, {
        String? cidade,
      }) async {
    final res = await api.get<dynamic>(
      '/exames/prestadores-especialidade',
      queryParameters: {
        'especialidade': especialidade,
        if (cidade != null && cidade.isNotEmpty) 'cidade': cidade,
      },
    );

    final body = _expectOkEnvelope(res);
    final rows = _extractRows(body);

    return rows
        .map((r) => PrestadorRow.fromJson(r))
        .toList(growable: false);
  }

  // ------------------------ Busca por nome ------------------------

  /// Busca prestadores por nome para enriquecer cards (endereço/especialidade).
  ///
  /// GET /api/v1/catalogo-assistencia/prestadores-buscar?q=...&limit=N
  Future<List<PrestadorRow>> buscarPorNome(
      String nome, {
        int limit = 10,
      }) async {
    final res = await api.get<dynamic>(
      '/catalogo-assistencia/prestadores-buscar',
      queryParameters: {
        'q': nome,
        'limit': limit,
      },
    );

    final body = _expectOkEnvelope(res);
    final rows = _extractRows(body);

    return rows
        .map((r) => PrestadorRow.fromJson(r))
        .toList(growable: false);
  }
}
