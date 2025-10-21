// lib/repositories/exames_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import '../models/exame.dart';
import '../services/dev_api.dart';

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
    final pendentes = rows
        .where((r) {
      final m = (r as Map);
      final st = (m['auditado'] ?? '').toString().trim().toUpperCase();
      return st == 'P';
    })
        .map((r) => ExameResumo.fromJson((r as Map).cast<String, dynamic>()))
        .toList();

    if (limit > 0 && pendentes.length > limit) {
      return pendentes.take(limit).toList();
    }
    return pendentes;
  }

  /// Lista as autorizações liberadas (status 'A')
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
      return st == 'A'; // Auditada/Aprovada
    })
        .map((r) => ExameResumo.fromJson((r as Map).cast<String, dynamic>()))
        .toList();

    if (limit > 0 && liberadas.length > limit) {
      return liberadas.take(limit).toList();
    }
    return liberadas;
  }

  /// Marca a autorização como "R" (primeira impressão/conclusão).
  /// No backend, mapeie para a action `exame_concluir` que chama
  /// `SpConcluiAutorizacaoExamesRepository`.
  Future<void> registrarPrimeiraImpressao(int numero) async {
    try {
      final res = await _api.postAction('exame_concluir', data: {
        'numero': numero,
      });

      final body = res.data as Map?;
      if (body != null && body['ok'] != true) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
          error: body['error'],
        );
      }
    } on DioException {
      rethrow; // deixe estourar para a UI tratar se necessário
    } catch (e) {
      if (kDebugMode) {
        // Em release, silencioso; em debug, útil para diagnóstico.
        // ignore: avoid_print
        print('registrarPrimeiraImpressao falhou: $e');
      }
      // Não rethrow em erro genérico para não travar o fluxo de impressão.
    }
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

    // o endpoint retorna algo como { ok: true, data: { dados: {...} } } ou { ok, data: {...} }
    final data = (body['data'] as Map).cast<String, dynamic>();
    final map =
    (data['dados'] is Map) ? (data['dados'] as Map).cast<String, dynamic>() : data;
    return ExameDetalhe.fromJson(map);
  }
}
