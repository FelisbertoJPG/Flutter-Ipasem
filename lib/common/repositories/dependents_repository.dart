
// lib/repositories/dependents_repository.dart
import '../config/dev_api.dart';
import '../models/dependent.dart';

class DependentsRepository {
  final DevApi api;
  DependentsRepository(this.api);

  Future<List<Dependent>> listByMatricula(int idMatricula) {
    return api.fetchDependentes(idMatricula);
  }
}
