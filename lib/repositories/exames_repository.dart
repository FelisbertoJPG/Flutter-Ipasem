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
      final res = await _api.postAction('exame_concluir', data: {'numero': numero});
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
      rethrow; // se quiser tratar na UI
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('registrarPrimeiraImpressao falhou: $e');
      }
      // silencioso em erro genérico pra não travar o fluxo
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

    final data = (body['data'] as Map).cast<String, dynamic>();
    final map = (data['dados'] is Map)
        ? (data['dados'] as Map).cast<String, dynamic>()
        : data;

    return ExameDetalhe.fromJson(map);
  }
  Future<List<ExameResumo>> listarNegadas({
    required int idMatricula,
    int limit = 5, // 5 para a Home; use 0 para "todas"
  }) async {
    // Mesma convenção das outras chamadas
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

    // helpers locais
    String _mkDataHora(Map<String, dynamic> r) {
      final d = (r['data_emissao'] ?? '').toString().trim();
      final h = (r['hora_emissao'] ?? '').toString().trim();
      if (d.isNotEmpty && h.isNotEmpty) return '$d • $h';
      if (d.isNotEmpty) return d;
      return h;
    }

    DateTime _parseDateTime(Map<String, dynamic> r) {
      try {
        final d = (r['data_emissao'] ?? '').toString().trim();
        final h = (r['hora_emissao'] ?? '').toString().trim();
        final t = h.isEmpty ? '00:00' : h;
        if (d.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);

        final p = d.split('/');
        if (p.length == 3) {
          final dd = int.tryParse(p[0]) ?? 1;
          final mm = int.tryParse(p[1]) ?? 1;
          var yy = int.tryParse(p[2]) ?? 1970;
          if (yy < 100) yy += 2000; // normaliza yy->yyyy
          final th = t.split(':');
          final hh = int.tryParse(th[0]) ?? 0;
          final mi = (th.length > 1) ? int.tryParse(th[1]) ?? 0 : 0;
          return DateTime(yy, mm, dd, hh, mi);
        }
        return DateTime.fromMillisecondsSinceEpoch(0);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    // filtra status 'I' (negado), normalizando o campo
    final negadas = rows.where((r) {
      final m = (r as Map).cast<String, dynamic>();
      final st = (m['auditado'] ?? '').toString().trim().toUpperCase();
      return st == 'I';
    }).map((r) => (r as Map).cast<String, dynamic>()).toList();

    // ordena mais recentes primeiro
    negadas.sort((a, b) => _parseDateTime(b).compareTo(_parseDateTime(a)));

    // limita se solicitado
    final cut = (limit > 0) ? negadas.take(limit).toList() : negadas;

    // mapeia para ExameResumo (mantendo seu modelo atual)
    return cut.map<ExameResumo>((r) {
      final numero   = int.tryParse('${r['nro_autorizacao'] ?? 0}') ?? 0;
      final paciente = (r['nome_dependente'] ?? '').toString();
      final prestador= (r['nome_prestador'] ?? '').toString();
      final dataHora = _mkDataHora(r);
      return ExameResumo(
        numero: numero,
        paciente: paciente,
        prestador: prestador,
        dataHora: dataHora,
      );
    }).toList();
  }

}
