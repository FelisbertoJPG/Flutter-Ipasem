import 'package:dio/dio.dart';
import '../services/dev_api.dart';

class AutorizacoesRepository {
  final DevApi api;
  AutorizacoesRepository(this.api);

  Future<int> gravar({
    required int idMatricula,
    required int idDependente,
    required int idEspecialidade,
    required int idPrestador,
    required String tipoPrestador,
  }) async {

    final res = await api.post(
      '/api-dev.php?action=gravar_autorizacao',
      data: {
        'id_matricula':     idMatricula,
        'id_dependente':    idDependente,
        'id_especialidade': idEspecialidade,
        'id_prestador':     idPrestador,
        'tipo_prestador':   tipoPrestador,
      },
    );

    final body = (res.data as Map).cast<String, dynamic>();
    if (body['ok'] == true) {
      final data = (body['data'] as Map?) ?? const {};
      final raw  = data['o_nro_autorizacao'] ?? data['numero'];
      final numAut = raw is int ? raw : int.tryParse('$raw') ?? 0;
      if (numAut <= 0) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
          error: 'Resposta inválida do backend.',
        );
      }
      return numAut;
    }

    // devolve o erro “cru” do PHP (inclui BUSINESS_RULE)
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'],
    );
  }
}
