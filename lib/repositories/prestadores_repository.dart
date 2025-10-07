import '../services/dev_api.dart';
import '../models/prestador.dart';

class PrestadoresRepository {
  final DevApi api;
  PrestadoresRepository(this.api);

  Future<List<String>> cidadesDisponiveis(int codEspecialidade) =>
      api.fetchCidadesPorEspecialidade(codEspecialidade);

  Future<List<PrestadorRow>> porEspecialidade(int codEspecialidade, {String? cidade}) =>
      api.fetchPrestadoresPorEspecialidade(especialidade: codEspecialidade, cidade: cidade);
}
