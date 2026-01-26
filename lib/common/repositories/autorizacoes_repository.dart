// lib/repositories/autorizacoes_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, debugPrint;
import 'package:image_picker/image_picker.dart';

import '../config/dev_api.dart';

class AutorizacoesRepository {
  final DevApi api;
  AutorizacoesRepository(this.api);

  /// Grava autorização Médico / Odonto.
  ///
  /// POST /api/v1/autorizacao/gravar
  Future<int> gravar({
    required int idMatricula,
    required int idDependente,
    required int idEspecialidade,
    required int idPrestador,
    required String tipoPrestador,
  }) async {
    final res = await api.post(
      '/autorizacao/gravar',
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

  /// Grava autorização de EXAMES.
  ///
  /// POST /api/v1/exame/gravar
  Future<int> gravarExame({
    required int idMatricula,
    required int idDependente,
    required int idPrestador,
    required String tipoPrestador,
  }) async {
    final res = await api.post(
      '/exame/gravar',
      data: {
        'id_matricula':   idMatricula,
        'id_dependente':  idDependente,
        'id_prestador':   idPrestador,
        'tipo_prestador': tipoPrestador,
      },
    );

    // Assume o mesmo envelope { ok, data: { o_nro_autorizacao|numero } }
    return _extractNumeroOrThrow(res);
  }

  /// Upload das imagens da requisição do exame (até 2).
  ///
  /// POST /api/v1/exame/upload-imagens (multipart/form-data)
  Future<void> enviarImagensExame({
    required int numero,
    required List<XFile> files,
  }) async {
    if (files.isEmpty) return;

    // Util para extrair um nome de arquivo consistente.
    String _fileName(XFile x) {
      if (x.name.isNotEmpty) return x.name;
      final p = x.path;
      final a = p.split('/').last;
      return a.split(r'\').last;
    }

    final form = FormData();

    // Campo simples
    form.fields.add(MapEntry('numero', '$numero'));

    // Máx 2 imagens, todas no campo "images"
    for (final x in files.take(2)) {
      final fname = _fileName(x);
      if (kIsWeb) {
        final bytes = await x.readAsBytes();
        form.files.add(
          MapEntry(
            'images',
            MultipartFile.fromBytes(bytes, filename: fname),
          ),
        );
      } else {
        form.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(
              x.path,
              filename: fname,
            ),
          ),
        );
      }
    }

    try {
      final res = await api.post<Map<String, dynamic>>(
        '/exame/upload-imagens',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );

      final body = res.data ?? const <String, dynamic>{};
      if (body['ok'] != true) {
        if (!kReleaseMode) debugPrint('Upload error body: $body');
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
          error: body['error'] ?? 'Falha no upload das imagens.',
        );
      }
    } on DioException catch (e) {
      if (!kReleaseMode) {
        debugPrint(
          'Upload DioException: status=${e.response?.statusCode} '
              'data=${e.response?.data}',
        );
      }
      rethrow;
    }
  }

  // ----------------- Helpers -----------------

  /// Lê `{ ok: true, data: { o_nro_autorizacao|numero } }` e devolve o número.
  int _extractNumeroOrThrow(Response res) {
    final body = (res.data as Map).cast<String, dynamic>();

    if (body['ok'] == true) {
      final data = (body['data'] as Map?) ?? const {};
      final raw = data['o_nro_autorizacao'] ?? data['numero'];

      final numAut = raw is int ? raw : int.tryParse('$raw') ?? 0;
      if (numAut > 0) return numAut;

      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: 'Resposta inválida do backend (sem número).',
      );
    }

    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'] ?? 'Falha ao gravar autorização',
    );
  }
}
