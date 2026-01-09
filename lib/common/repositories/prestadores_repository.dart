// lib/repositories/prestadores_repository.dart
import 'package:dio/dio.dart';
import '../config/dev_api.dart';
import '../models/prestador.dart';

class PrestadoresRepository {
  final DevApi api;
  PrestadoresRepository(this.api);

  // ---- Já existentes (mantidos) ----
  Future<List<String>> cidadesDisponiveis(int especialidade) =>
      api.fetchCidadesPorEspecialidade(especialidade);

  Future<List<PrestadorRow>> porEspecialidade(
      int especialidade, {
        String? cidade,
      }) =>
      api.fetchPrestadoresPorEspecialidade(
        especialidade: especialidade,
        cidade: cidade,
      );

  // ---- Variantes para EXAMES (mantidos) ----
  Future<List<String>> cidadesDisponiveisExames(int especialidade) =>
      api.fetchCidadesPorEspecialidadeExames(especialidade);

  Future<List<PrestadorRow>> porEspecialidadeExames(
      int especialidade, {
        String? cidade,
      }) =>
      api.fetchPrestadoresPorEspecialidadeExames(
        especialidade: especialidade,
        cidade: cidade,
      );

  // ---- NOVO: busca por nome (usado no card para enriquecer endereço/especialidade) ----
  Future<List<PrestadorRow>> buscarPorNome(String nome, {int limit = 10}) async {
    final res = await api.postAction('prestadores_buscar', data: {
      'q': nome,
      'limit': limit,
    });

    final body = res.data as Map;
    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: body['error'] ?? 'Falha ao buscar prestadores.',
      );
    }

    final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];
    return rows
        .map((r) => PrestadorRow.fromJson((r as Map).cast<String, dynamic>()))
        .toList();
  }
}
