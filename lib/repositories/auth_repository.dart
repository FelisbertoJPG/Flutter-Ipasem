// lib/repositories/auth_repository.dart
import '../services/dev_api.dart';
import '../models/profile.dart';

class AuthRepository {
  final DevApi api;
  AuthRepository(this.api);

  Future<Profile> login(String cpf, String senha) async {
    final map = await api.login(cpf: cpf, senha: senha);
    return Profile.fromMap(map);
  }
}
