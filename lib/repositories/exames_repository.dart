import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import '../services/dev_api.dart';
import '../models/exame.dart';

class ExamesRepository {
  final DevApi _api;
  ExamesRepository(this._api);

  Future<List<ExameResumo>> listarPendentes({
    required int idMatricula,
    int limit = 4,
  }) async {
    final res = await _api.postAction('exames_historico', data: {
      'id_matricula': idMatricula,
    });

    final body = res.data as Map;
    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: body['error'],
      );
    }

    final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];
    final pendentes = rows.where((r) {
      final m = (r as Map);
      final st = (m['auditado'] ?? '').toString().trim().toUpperCase();
      return st == 'P';
    }).map((r) => ExameResumo.fromJson((r as Map).cast<String, dynamic>()))
        .toList();

    if (limit > 0 && pendentes.length > limit) {
      return pendentes.take(limit).toList();
    }
    return pendentes;
  }

  Future<List<ExameResumo>> listarLiberadas({
    required int idMatricula,
    int limit = 4,
  }) async {
    final res = await _api.postAction('exames_historico', data: {
      'id_matricula': idMatricula,
    });

    final body = res.data as Map;
    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: body['error'],
      );
    }

    final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];
    final liberadas = rows
        .where((r) {
      final m = (r as Map);
      final st = (m['auditado'] ?? '').toString().trim().toUpperCase();
      return st == 'A'; // auditado/aprovado
    })
        .map((r) => ExameResumo.fromJson((r as Map).cast<String, dynamic>()))
        .toList();

    if (limit > 0 && liberadas.length > limit) {
      return liberadas.take(limit).toList();
    }
    return liberadas;
  }

  Future<ExameDetalhe> consultarDetalhe({
    required int numero,
    required int idMatricula,
  }) async {
    final res = await _api.postAction('exame_consulta', data: {
      'numero': numero,
      'id_matricula': idMatricula,
    });

    final body = res.data as Map;
    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: body['error'],
      );
    }

    final data = (body['data'] as Map).cast<String, dynamic>();
    final map  = (data['dados'] is Map) ? (data['dados'] as Map).cast<String, dynamic>() : data;
    return ExameDetalhe.fromJson(map);
  }

  /// Marca a autorização como reimpressão (A -> R) no servidor.
  /// Tenta `exame_registrar_primeira_impressao`; em caso de falha, faz fallback para `exame_concluir`.
  Future<void> registrarPrimeiraImpressao({
    required int numero,
    required int idMatricula,
  }) async {
    try {
      final res = await _api.postAction(
        'exame_registrar_primeira_impressao',
        data: {'numero': numero, 'id_matricula': idMatricula},
      );
      final body = res.data as Map;
      if (body['ok'] == true) {
        if (kDebugMode) print('[repo] primeira impressão registrada: $numero');
        return;
      }
      if (kDebugMode) print('[repo] retorno não-ok, fallback concluir: $body');
      await concluir(numero: numero);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('[repo] registrarPrimeiraImpressao DioException: ${e.message} / ${e.response?.data}');
      }
      await concluir(numero: numero);
    } catch (e) {
      if (kDebugMode) print('[repo] registrarPrimeiraImpressao erro genérico: $e');
      await concluir(numero: numero);
    }
  }

  /// Fallback genérico (e também pode ser chamado diretamente).
  Future<void> concluir({required int numero}) async {
    final res = await _api.postAction('exame_concluir', data: {'numero': numero});
    final body = res.data as Map;
    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: body['error'] ?? 'Falha ao concluir autorização.',
      );
    }
    if (kDebugMode) print('[repo] concluído (A->R): $numero');
  }
}