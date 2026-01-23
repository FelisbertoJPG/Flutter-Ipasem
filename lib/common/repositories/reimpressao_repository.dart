// lib/repositories/reimpressao_repository.dart
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/dev_api.dart';
import '../models/reimpressao.dart';

class ReimpressaoRepository {
  final DevApi api;
  ReimpressaoRepository(this.api);

  // ===========================================================================
  // Helpers internos
  // ===========================================================================

  Map<String, dynamic> _expectOkEnvelope(Response res) {
    final data = res.data;
    if (data is! Map) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: 'Resposta inválida (não é JSON objeto).',
      );
    }

    final body = data.cast<String, dynamic>();
    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: body['error'] ?? body,
      );
    }

    return body;
  }

  // ===========================================================================
  // Histórico de autorizações (reimpressão)
  //   POST /api/v1/autorizacao/reimpressao-historico
  // ===========================================================================

  Future<List<ReimpressaoResumo>> historico({
    required int idMatricula,
  }) async {
    final res = await api.post<dynamic>(
      '/autorizacao/reimpressao-historico',
      data: {
        // padronizando com underscore na nova API
        'id_matricula': idMatricula,
      },
    );

    final body = _expectOkEnvelope(res);
    final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];

    return rows
        .whereType<Map>()
        .map((m) => ReimpressaoResumo.fromMap(m.cast<String, dynamic>()))
        .toList(growable: false);
  }

  // ===========================================================================
  // Detalhe bruto (dados + itens)
  //   POST /api/v1/autorizacao/reimpressao-detalhe
  // ===========================================================================

  /// Payload bruto de reimpressão (traz dados + itens).
  /// Mantém o envelope `{ ok, data, error, meta }`.
  Future<Map<String, dynamic>> detalheRaw(
      int numero, {
        required int idMatricula,
      }) async {
    final res = await api.post<dynamic>(
      '/autorizacao/reimpressao-detalhe',
      data: {
        'numero': numero,
        'id_matricula': idMatricula,
      },
    );

    // Lança se `ok != true`
    final body = _expectOkEnvelope(res);
    return body;
  }

  // ===========================================================================
  // Detalhe mapeado (para telas que só precisam dos campos principais)
  // ===========================================================================

  Future<ReimpressaoDetalhe?> detalhe(
      int numero, {
        required int idMatricula,
      }) async {
    final body = await detalheRaw(numero, idMatricula: idMatricula);

    final row = (body['data'] is Map)
        ? ((body['data'] as Map)['row'] as Map?)?.cast<String, dynamic>()
        : null;

    return row == null ? null : ReimpressaoDetalhe.fromMap(row);
  }

  // ===========================================================================
  // Baixar PDF renderizado no backend
  //   POST /api/v1/autorizacao/reimpressao-pdf
  // ===========================================================================

  /// Baixa o PDF gerado pelo backend.
  ///
  /// Observação: endpoint REST novo
  ///   POST /api/v1/autorizacao/reimpressao-pdf
  ///
  /// Esperado:
  ///   - Sucesso: status 200 + bytes do PDF
  ///   - Erro: status != 200 ou JSON com { ok: false, error: '...' }
  Future<Uint8List> baixarPdf({
    required int numero,
    required int idMatricula,
    required String nomeTitular,
  }) async {
    final res = await api.post<dynamic>(
      '/autorizacao/reimpressao-pdf',
      data: {
        'numero': '$numero',
        'id_matricula': '$idMatricula',
        'nome_titular': nomeTitular,
      },
      options: Options(
        // Sobrescreve o default JSON para receber bytes
        responseType: ResponseType.bytes,
        headers: {
          Headers.contentTypeHeader: Headers.formUrlEncodedContentType,
        },
      ),
    );

    // Sucesso: bytes do PDF
    if (res.statusCode == 200 && res.data is List<int>) {
      return Uint8List.fromList(res.data as List<int>);
    }

    // Se o backend respondeu JSON com erro (ou outro formato), tenta interpretar
    try {
      if (res.data is Map) {
        final body = (res.data as Map).cast<String, dynamic>();
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
          error: body['error'] ?? 'Falha ao gerar PDF.',
        );
      }
    } catch (_) {
      // cai no fallback genérico abaixo
    }

    // Fallback genérico
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: 'Falha ao gerar PDF (${res.statusCode ?? 0}).',
    );
  }
}
