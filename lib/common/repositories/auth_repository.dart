// lib/common/repositories/auth_repository.dart
import 'package:dio/dio.dart';

import '../../backend/exception/app_exception.dart';
import '../../backend/exception/dio_error_mapper.dart';
import '../models/profile.dart';
import '../config/dev_api.dart';

class AuthRepository {
  final DevApi api;
  AuthRepository(this.api);

  /// Login do TITULAR (CPF + senha)
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

  /// Login do DEPENDENTE (CPF + senha) – ETAPA 1
  ///
  /// Retorna:
  ///   (Profile, List<Map<String,dynamic>>)
  ///   onde a lista contém os vínculos (titulares) retornados pela API.
  Future<(Profile, List<Map<String, dynamic>>)> loginDependente(
      String cpf,
      String senha,
      ) async {
    try {
      // DevApi.loginDependente agora retorna o "data" da resposta:
      // {
      //   "profile": { ... },
      //   "vinculos": [ {...}, {...} ]
      // }
      final data = await api.loginDependente(
        cpf: cpf,
        senha: senha,
      );

      final profileMap =
          (data['profile'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};

      final profile = Profile.fromMap(profileMap);

      final vinculosRaw = (data['vinculos'] as List?) ?? const [];
      final vinculos = vinculosRaw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

      return (profile, vinculos);
    } on DioException catch (e) {
      throw mapDioError(e);
    } catch (_) {
      throw const UnexpectedException();
    }
  }
}
