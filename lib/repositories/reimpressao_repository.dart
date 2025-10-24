// lib/repositories/reimpressao_repository.dart
import 'dart:typed_data';
import 'package:dio/dio.dart';

import '../services/dev_api.dart';
import '../models/reimpressao.dart';

class ReimpressaoRepository {
  final DevApi api;
  ReimpressaoRepository(this.api);

  // Histórico de autorizações (reimpressão)
  Future<List<ReimpressaoResumo>> historico({required int idMatricula}) async {
    final res = await api.postAction('reimpressao_historico', data: {
      'idmatricula': idMatricula,
    });

    final body = (res.data as Map).cast<String, dynamic>();
    if (body['ok'] == true) {
      final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];
      return rows
          .cast<Map>()
          .map((m) => ReimpressaoResumo.fromMap(m.cast<String, dynamic>()))
          .toList();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'],
    );
  }

  // Detalhe (sempre informando a matrícula para o backend injetar a identity)
  Future<ReimpressaoDetalhe?> detalhe(int numero, {required int idMatricula}) async {
    final res = await api.postAction('reimpressao_detalhe', data: {
      'numero': numero,
      'idmatricula': idMatricula,
    });

    final body = (res.data as Map).cast<String, dynamic>();
    if (body['ok'] == true) {
      final row = (body['data']?['row'] as Map?)?.cast<String, dynamic>();
      return row == null ? null : ReimpressaoDetalhe.fromMap(row);
    }

    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: body['error'],
    );
  }

  // Baixa o PDF como bytes (para abrir nativamente no dispositivo, se você desejar)
  Future<Uint8List> baixarPdf({
    required int numero,
    required int idMatricula,
    required String nomeTitular,
  }) async {
    final res = await api.post(
      '/api-dev.php?action=reimpressao_pdf',
      data: {
        'numero': '$numero',
        'idmatricula': '$idMatricula',
        'nome_titular': nomeTitular,
      },
      options: Options(
        headers: {'Content-Type': Headers.formUrlEncodedContentType},
        responseType: ResponseType.bytes,
      ),
    );

    // Quando o backend renderiza PDF, a resposta correta vem em bytes (status 200).
    if (res.statusCode == 200 && res.data is List<int>) {
      return Uint8List.fromList(res.data as List<int>);
    }

    // Se vier JSON de erro (ex.: NOT_FOUND, REIMP_PDF_ERROR, etc.), propaga como DioException.
    try {
      final body = (res.data as Map).cast<String, dynamic>();
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: body['error'] ?? 'Falha ao gerar PDF.',
      );
    } catch (_) {
      // fallback genérico
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: 'Falha ao gerar PDF (${res.statusCode}).',
      );
    }
  }
}
