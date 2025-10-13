import '../services/dev_api.dart';
import '../models/prestador.dart';

class PrestadoresRepository {
  final DevApi api;
  PrestadoresRepository(this.api);

  // já existia:
  Future<List<String>> cidadesDisponiveis(int especialidade) =>
      api.fetchCidadesPorEspecialidade(especialidade);

  Future<List<PrestadorRow>> porEspecialidade(int especialidade, {String? cidade}) =>
      api.fetchPrestadoresPorEspecialidade(especialidade: especialidade, cidade: cidade);

  // NOVOS: variantes para EXAMES
  Future<List<String>> cidadesDisponiveisExames(int especialidade) =>
      api.fetchCidadesPorEspecialidadeExames(especialidade);

  Future<List<PrestadorRow>> porEspecialidadeExames(int especialidade, {String? cidade}) =>
      api.fetchPrestadoresPorEspecialidadeExames(especialidade: especialidade, cidade: cidade);
}
