import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../services/dev_api.dart';
import '../models/reimpressao.dart';

class ReimpressaoRepository {
  final DevApi api;
  ReimpressaoRepository(this.api);

  Future<List<ReimpressaoResumo>> historico({required int idMatricula}) async {
    final res = await api.post(
      '/api-dev.php?action=reimpressao_historico',
      data: {'idmatricula': idMatricula},
    );
    final body = (res.data as Map).cast<String, dynamic>();
    if (body['ok'] == true) {
      final rows = (body['data']?['rows'] as List?) ?? const [];
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

  Future<ReimpressaoDetalhe?> detalhe(int numero, {int? idMatricula}) async {
    final res = await api.post(
      '/api-dev.php?action=reimpressao_detalhe',
      data: {
        'numero': numero,
        if (idMatricula != null) 'idmatricula': idMatricula,
      },
    );
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

  /// URL para abrir/baixar o PDF no navegador
  // ReimpressaoRepository
  String pdfUrl({
    required int numero,
    required int idMatricula,
    String? nomeTitular,
    bool download = false,
  }) {
    final qp = <String, String>{
      'action': 'reimpressao_pdf',
      'numero': '$numero',
      'idmatricula': '$idMatricula',
      if (nomeTitular != null && nomeTitular.isNotEmpty) 'nome_titular': nomeTitular,
      if (download) 'download': '1',
    };

    // Em debug, adiciona &debug=1 pra gente ver no servidor o que chegou
    assert(() {
      qp['debug'] = '1';
      return true;
    }());

    final uri = Uri.parse(api.endpoint).replace(queryParameters: qp);
    return uri.toString();
  }


  /// Baixa o PDF como bytes (para salvar/abrir nativamente)
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

    if (res.statusCode == 200 && res.data is List<int>) {
      return Uint8List.fromList(res.data as List<int>);
    }
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: 'Falha ao gerar PDF (${res.statusCode})',
    );
  }
}
