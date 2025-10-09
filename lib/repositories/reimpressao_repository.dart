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
}
