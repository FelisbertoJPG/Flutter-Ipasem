// lib/repositories/auth_repository.dart (trecho relevante)
import 'package:dio/dio.dart';
import '../../backend/exception/app_exception.dart';
import '../../backend/exception/dio_error_mapper.dart';
import '../models/profile.dart';
import '../config/dev_api.dart';

class AuthRepository {
  final DevApi api;
  AuthRepository(this.api);

  Future<Profile> login(String cpf, String senha) async {
    try {
      final m = await api.login(cpf: cpf, senha: senha);
      return Profile.fromMap(m);
    } on DioException catch (e) {
      throw mapDioError(e);
    } catch (_) {
      throw const UnexpectedException();
    }
  }
}