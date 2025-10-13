import 'package:dio/dio.dart';
import '../services/dev_api.dart';

class AutorizacoesRepository {
  final DevApi api;
  AutorizacoesRepository(this.api);

  /// Médico / Odonto
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
    return _extractNumeroOrThrow(res);
  }

  /// Exames (usa SP de exames; sem obrigatoriedade de id_especialidade)
  Future<int> gravarExame({
    required int idMatricula,
    required int idDependente,
    required int idPrestador,
    required String tipoPrestador,
  }) async {
    final res = await api.postAction<Map<String, dynamic>>(
      'gravar_exame',
      data: {
        'id_matricula':   idMatricula,
        'id_dependente':  idDependente,
        'id_prestador':   idPrestador,
        'tipo_prestador': tipoPrestador,
      },
    );
    final body = (res.data ?? {});
    if (body['ok'] == true) {
      final data = (body['data'] as Map?) ?? const {};
      final raw  = data['o_nro_autorizacao'] ?? data['numero'];
      final numAut = raw is int ? raw : int.tryParse('$raw') ?? 0;
      if (numAut > 0) return numAut;
    }
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'],
    );
  }

  // ----------------- Helpers -----------------

  int _extractNumeroOrThrow(Response res) {
    final body = (res.data as Map).cast<String, dynamic>();
    if (body['ok'] == true) {
      final data = (body['data'] as Map?) ?? const {};
      final raw  = data['o_nro_autorizacao'] ?? data['numero'];
      final numAut = raw is int ? raw : int.tryParse('$raw') ?? 0;
      if (numAut > 0) return numAut;
      // se 'ok' veio true mas sem número válido:
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: 'Resposta inválida do backend (sem número).',
      );
    }

    // devolve o erro “cru” do backend (inclui BUSINESS_RULE)
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'] ?? 'Falha ao gravar autorização',
    );
  }
  /// NOVO: upload das imagens da requisição do exame (até 2)
  Future<void> enviarImagensExame({
    required int numero,
    required List<String> paths,
  }) async {
    if (paths.isEmpty) return;

    final files = <String, List<MultipartFile>>{
      'images[]': [
        for (final p in paths.take(2))
          await MultipartFile.fromFile(p, filename: p.split('/').last),
      ],
    };

    final res = await api.uploadAction(
      'upload_exame_imagens',
      fields: {'numero': numero},
      files: files,
    );

    final body = (res.data as Map).cast<String, dynamic>();
    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: body['error'] ?? 'Falha no upload das imagens.',
      );
    }
  }
}
