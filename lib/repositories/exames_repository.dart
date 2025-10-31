// lib/repositories/exames_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import '../models/exame.dart';
import '../services/dev_api.dart';
import '../state/auth_events.dart';

class ExamesRepository {
  ExamesRepository(this._api);
  final DevApi _api;

  // --------------------------------- Constantes de status ---------------------------------
  static const _stPendente  = 'P';
  static const _stAprovado  = 'A';
  static const _stImpresso  = 'R';
  static const _stIndeferido = 'I';

  // --------------------------------- Utilidades privadas ----------------------------------

  /// Converte os campos `data_emissao` e `hora_emissao` (ou variações)
  /// em `DateTime`. Aceita:
  /// - "dd/MM/yyyy" com hora opcional "HH:mm" ou "HH:mm:ss"
  /// - "yyyy-MM-dd" com hora opcional "HH:mm" ou "HH:mm:ss"
  /// - Casos em que a hora já veio “colada” na data (ex.: "dd/MM/yyyy HH:mm")
  DateTime _parseRowDate(Map<String, dynamic> j) {
    try {
      String d = (j['data_emissao'] ?? '').toString().trim();
      String h = (j['hora_emissao'] ?? '').toString().trim();

      // Se a data já vier com hora no mesmo campo, divide.
      if (h.isEmpty && d.contains(' ')) {
        final parts = d.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          d = parts.first;
          h = parts.last;
        }
      }

      if (d.isEmpty && h.isEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }

      // Normaliza hora para HH:mm:ss
      String _normalizeH(String raw) {
        if (raw.isEmpty) return '00:00:00';
        final segs = raw.split(':');
        if (segs.length == 1) return '${segs[0]}:00:00';
        if (segs.length == 2) return '${segs[0]}:${segs[1]}:00';
        return '${segs[0]}:${segs[1]}:${segs[2]}';
      }

      // Formato ISO-like? (yyyy-MM-dd)
      if (d.contains('-')) {
        final hh = _normalizeH(h);
        final iso = '${d}T$hh';
        final dt = DateTime.tryParse(iso);
        return dt ?? DateTime.fromMillisecondsSinceEpoch(0);
      }

      // Caso padrão: dd/MM/yyyy
      final p = d.split('/');
      if (p.length == 3) {
        final dd = int.tryParse(p[0]) ?? 1;
        final mm = int.tryParse(p[1]) ?? 1;
        var yy   = int.tryParse(p[2]) ?? 1970;
        if (yy < 100) yy += 2000;

        final nh = _normalizeH(h).split(':');
        final hh = int.tryParse(nh[0]) ?? 0;
        final mi = int.tryParse(nh[1]) ?? 0;
        final ss = int.tryParse(nh[2]) ?? 0;

        return DateTime(yy, mm, dd, hh, mi, ss);
      }

      return DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  DateTime _parseResumoDate(ExameResumo r) {
    try {
      // dataHora costuma estar no formato "dd/MM/yyyy • HH:mm" ou "dd/MM/yyyy HH:mm"
      final raw = r.dataHora.replaceAll('•', ' ').trim();
      final parts = raw.split(RegExp(r'\s+'));
      final d = parts.isNotEmpty ? parts.first : '';
      final h = parts.length > 1 ? parts.last : '';
      return _parseRowDate({'data_emissao': d, 'hora_emissao': h});
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchHistoricoRaw(int idMatricula) async {
    final res = await _api.postAction('exames_historico', data: {
      'id_matricula': idMatricula,
    });

    final body = (res.data as Map).cast<String, dynamic>();
    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: body['error'],
      );
    }

    final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList(growable: false);
  }

  // --------------------------------- Listagens para a Home --------------------------------

  /// Últimos exames nos status 'A' (liberado) **ou** 'P' (pendente),
  /// ordenados do mais recente para o mais antigo. O `limit` é aplicado após a ordenação.
  Future<List<ExameResumo>> listarUltimosAP({
    required int idMatricula,
    int limit = 3,
  }) async {
    final rows = await _fetchHistoricoRaw(idMatricula);

    final ap = rows.where((m) {
      final st = (m['auditado'] ?? '').toString().trim().toUpperCase();
      return st == _stAprovado || st == _stPendente;
    }).toList();

    ap.sort((a, b) => _parseRowDate(b).compareTo(_parseRowDate(a)));

    final mapped = ap.map((m) => ExameResumo.fromJson(m)).toList();
    if (limit > 0 && mapped.length > limit) {
      return mapped.take(limit).toList();
    }
    return mapped;
  }

  /// Pendentes (status 'P') — ordenados do mais recente para o mais antigo.
  Future<List<ExameResumo>> listarPendentes({
    required int idMatricula,
    int limit = 4,
  }) async {
    final rows = await _fetchHistoricoRaw(idMatricula);

    final pendentes = rows.where((m) {
      final st = (m['auditado'] ?? '').toString().trim().toUpperCase();
      return st == _stPendente;
    }).toList();

    pendentes.sort((a, b) => _parseRowDate(b).compareTo(_parseRowDate(a)));

    final mapped = pendentes.map((m) => ExameResumo.fromJson(m)).toList();
    if (limit > 0 && mapped.length > limit) {
      return mapped.take(limit).toList();
    }
    return mapped;
  }

  /// Liberadas (status 'A') — ordenadas do mais recente para o mais antigo.
  Future<List<ExameResumo>> listarLiberadas({
    required int idMatricula,
    int limit = 4,
  }) async {
    final rows = await _fetchHistoricoRaw(idMatricula);

    final liberadas = rows.where((m) {
      final st = (m['auditado'] ?? '').toString().trim().toUpperCase();
      return st == _stAprovado;
    }).toList();

    liberadas.sort((a, b) => _parseRowDate(b).compareTo(_parseRowDate(a)));

    final mapped = liberadas.map((m) => ExameResumo.fromJson(m)).toList();
    if (limit > 0 && mapped.length > limit) {
      return mapped.take(limit).toList();
    }
    return mapped;
  }

  // --------------------------- Histórico completo (tela de histórico) ---------------------

  /// Múltiplas requisições simultâneas para o mesmo `idMatricula` compartilham o mesmo Future.
  final Map<int, Future<List<ExameResumo>>> _inflightHistorico = {};

  /// Histórico geral (P, A, R, I) já ordenado do mais recente para o mais antigo.
  Future<List<ExameResumo>> listarHistoricoOrdenado({
    required int idMatricula,
  }) {
    if (_inflightHistorico.containsKey(idMatricula)) {
      return _inflightHistorico[idMatricula]!;
    }
    final fut = _listarHistoricoOrdenadoImpl(idMatricula).whenComplete(() {
      _inflightHistorico.remove(idMatricula);
    });
    _inflightHistorico[idMatricula] = fut;
    return fut;
  }

  Future<List<ExameResumo>> _listarHistoricoOrdenadoImpl(int idMatricula) async {
    final rows = await _fetchHistoricoRaw(idMatricula);
    final itens = rows.map((m) => ExameResumo.fromJson(m)).toList();
    itens.sort((a, b) => _parseResumoDate(b).compareTo(_parseResumoDate(a)));
    return itens;
  }

  // --------------------------------- Negadas (card da Home) --------------------------------

  Future<List<ExameResumo>> listarNegadas({
    required int idMatricula,
    int limit = 5, // 5 para a Home; use 0 para “todas”.
  }) async {
    final rows = await _fetchHistoricoRaw(idMatricula);

    String _mkDataHora(Map<String, dynamic> r) {
      final d = (r['data_emissao'] ?? '').toString().trim();
      final h = (r['hora_emissao'] ?? '').toString().trim();
      if (d.isNotEmpty && h.isNotEmpty) return '$d • $h';
      if (d.isNotEmpty) return d;
      return h;
    }

    final negadas = rows.where((m) {
      final st = (m['auditado'] ?? '').toString().trim().toUpperCase();
      return st == _stIndeferido;
    }).toList();

    negadas.sort((a, b) => _parseRowDate(b).compareTo(_parseRowDate(a)));

    final cut = (limit > 0) ? negadas.take(limit).toList() : negadas;

    return cut.map<ExameResumo>((r) {
      final numero    = int.tryParse('${r['nro_autorizacao'] ?? 0}') ?? 0;
      final paciente  = (r['nome_dependente'] ?? r['nome_paciente'] ?? '').toString();
      final prestador = (r['nome_prestador'] ?? r['nome_prestador_exec'] ?? '').toString();
      final dataHora  = _mkDataHora(r);
      return ExameResumo(
        numero: numero,
        paciente: paciente,
        prestador: prestador,
        dataHora: dataHora,
        status: _stIndeferido,
      );
    }).toList();
  }

  // --------------------------------- Detalhe -----------------------------------------------

  Future<ExameDetalhe> consultarDetalhe({
    required int numero,
    required int idMatricula,
  }) async {
    final res = await _api.postAction('exame_consulta', data: {
      'numero': numero,
      'id_matricula': idMatricula,
    });

    final body = (res.data as Map).cast<String, dynamic>();
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

  // --------------------------------- Conclusão (A -> R) ------------------------------------

  /// Marca a autorização como "R" (primeira impressão/conclusão).
  /// Use **somente após** o PDF ter sido aberto com sucesso (app externo/navegador).
  /// No backend, mapeia para `exame_concluir` → `SpConcluiAutorizacaoExamesRepository`.
  Future<void> registrarPrimeiraImpressao(int numero) async {
    try {
      final res = await _api.postAction('exame_concluir', data: {'numero': numero});
      final body = (res.data as Map?)?.cast<String, dynamic>();
      if (body != null && body['ok'] != true) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
          error: body['error'],
        );
      }

      // Notifica a aplicação; telas/listas podem reagir e recarregar.
      AuthEvents.instance.emitPrinted(numero);
      AuthEvents.instance.emitStatusChanged(numero, _stImpresso);
    } on DioException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('registrarPrimeiraImpressao falhou: $e');
      }
      // Silencioso em erro genérico para não quebrar fluxos da UI.
    }
  }
}
