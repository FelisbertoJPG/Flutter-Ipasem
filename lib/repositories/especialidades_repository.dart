import '../services/dev_api.dart';
import '../models/especialidade.dart';

class EspecialidadesRepository {
  final DevApi api;
  EspecialidadesRepository(this.api);

  Future<List<Especialidade>> listar() => api.fetchEspecialidades();
}
