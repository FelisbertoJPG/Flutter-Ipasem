// lib/common/repositories/auth_repository.dart
import 'package:dio/dio.dart';

import '../../backend/exception/app_exception.dart';
import '../../backend/exception/dio_error_mapper.dart';
import '../config/dev_api.dart';
import '../models/profile.dart';

class AuthRepository {
  final DevApi api;
  AuthRepository(this.api);

  /// Login do TITULAR (CPF + senha) via /api/v1/titular/login-repo
  Future<Profile> login(String cpf, String senha) async {
    try {
      final res = await api.postRest(
        '/titular/login-repo',
        data: {
          'cpf': cpf,
          'senha': senha,
        },
      );

      final body = (res.data as Map).cast<String, dynamic>();

      if (body['ok'] != true) {
        // Encapsula o erro da API em um DioException para passar pelo mapper
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
          error: body['error'],
        );
      }

      final data =
          (body['data'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

      // Se o backend embrulhar em "profile", usa; senão usa o próprio data como profile.
      final profileMap =
          (data['profile'] as Map?)?.cast<String, dynamic>() ?? data;

      return Profile.fromMap(profileMap);
    } on DioException catch (e) {
      throw mapDioError(e);
    } catch (_) {
      throw const UnexpectedException();
    }
  }

  /// Login do DEPENDENTE (CPF + senha) – ETAPA 1
  ///
  /// Endpoint: POST /api/v1/dependente/login
  ///
  /// Resposta esperada:
  /// {
  ///   "ok": true,
  ///   "data": {
  ///     "profile": { ... },
  ///     "vinculos": [ {...}, {...} ]
  ///   },
  ///   "error": null
  /// }
  Future<(Profile, List<Map<String, dynamic>>)> loginDependente(
      String cpf,
      String senha,
      ) async {
    try {
      final res = await api.postRest(
        '/dependente/login',
        data: {
          'cpf': cpf,
          'senha': senha,
        },
      );

      final body = (res.data as Map).cast<String, dynamic>();

      if (body['ok'] != true) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
          error: body['error'],
        );
      }

      final data =
          (body['data'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

      final profileMap =
          (data['profile'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final profile = Profile.fromMap(profileMap);

      final vinculosRaw = (data['vinculos'] as List?) ?? const [];
      final vinculos = vinculosRaw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false);

      return (profile, vinculos);
    } on DioException catch (e) {
      throw mapDioError(e);
    } catch (_) {
      throw const UnexpectedException();
    }
  }
}
