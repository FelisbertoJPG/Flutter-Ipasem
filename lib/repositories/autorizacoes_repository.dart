// lib/repositories/autorizacoes_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, debugPrint;
import 'package:image_picker/image_picker.dart';

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

  /// Exames
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

  /// Upload das imagens da requisição do exame (até 2).
  /// Recebe **XFile** para funcionar em mobile/desktop e também no **Web**.
  Future<void> enviarImagensExame({
    required int numero,
    required List<XFile> files,
  }) async {
    if (files.isEmpty) return;

    // util pra extrair um nome de arquivo consistente
    String _fileName(XFile x) {
      if (x.name.isNotEmpty) return x.name;
      final p = x.path;
      final a = p.split('/').last;
      return a.split(r'\').last;
    }

    final parts = <MultipartFile>[];
    for (final x in files.take(2)) {
      final fname = _fileName(x);
      if (kIsWeb) {
        final bytes = await x.readAsBytes();
        parts.add(MultipartFile.fromBytes(bytes, filename: fname));
      } else {
        parts.add(await MultipartFile.fromFile(x.path, filename: fname));
      }
    }

    try {
      final res = await api.uploadAction(
        'upload_exame_imagens',
        fields: {'numero': '$numero'},
        files: parts,                    // mesmo campo 'images' repetido (ver DevApi)
        fileFieldName: 'images',
      );

      final body = (res.data as Map).cast<String, dynamic>();
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
        debugPrint('Upload DioException: status=${e.response?.statusCode} data=${e.response?.data}');
      }
      rethrow;
    }
  }

  // ----------------- Helpers -----------------
  int _extractNumeroOrThrow(Response res) {
    final body = (res.data as Map).cast<String, dynamic>();
    if (body['ok'] == true) {
      final data = (body['data'] as Map?) ?? const {};
      final raw  = data['o_nro_autorizacao'] ?? data['numero'];
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
