// lib/common/services/carterinha_service/carteirinha_service.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../models/card_token.dart';
import '../../config/api_router.dart';
import '../../config/dev_api.dart';

class CarteirinhaService {
  final DevApi api;

  // ---------------------------------------------------------------------------
  // Construtores
  // ---------------------------------------------------------------------------

  CarteirinhaService._(this.api);

  /// Preferir quando há BuildContext (usa AppConfig / flavor para configurar a base).
  CarteirinhaService.fromContext(BuildContext context)
      : this._(_buildApiFromContext(context));

  /// Útil em camadas sem contexto; usa API_BASE/env (fallback PROD).
  CarteirinhaService({DevApi? api}) : this._(api ?? DevApi());

  static DevApi _buildApiFromContext(BuildContext context) {
    // Usa AppConfig, se disponível; senão cai no _ensureConfiguredSync do ApiRouter.
    ApiRouter.configureFromContext(context);
    // DevApi sempre usa ApiRouter.apiRootUri (ex.: https://host/api/v1).
    return DevApi();
  }

  // ---------------------------------------------------------------------------
  // Helpers HTTP
  // ---------------------------------------------------------------------------

  /// POST em [path] esperando um envelope `{ ok: true, data: {...} }`.
  /// Retorna sempre o `data` como `Map<String,dynamic>`.
  Future<Map<String, dynamic>> _postExpectOkData(
      String path, {
        Map<String, dynamic>? data,
      }) async {
    final res = await api.post<dynamic>(
      path,
      data: data,
    );

    final raw = res.data;
    if (raw is! Map) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: 'Resposta inválida do servidor (esperado JSON objeto).',
      );
    }

    final body = raw.cast<String, dynamic>();

    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: body['error'] ?? body['message'] ?? 'Falha na requisição.',
      );
    }

    final dataField = body['data'];
    if (dataField is Map) {
      return dataField.cast<String, dynamic>();
    }

    // Se não houver "data", devolve mapa vazio para evitar null.
    return <String, dynamic>{};
  }

  /// GET em [path] esperando envelope `{ ok: true, data: {...} }`.
  Future<Map<String, dynamic>> _getExpectOkData(
      String path, {
        Map<String, dynamic>? query,
      }) async {
    final res = await api.get<dynamic>(
      path,
      queryParameters: query,
    );

    final raw = res.data;
    if (raw is! Map) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: 'Resposta inválida do servidor (esperado JSON objeto).',
      );
    }

    final body = raw.cast<String, dynamic>();

    if (body['ok'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: body['error'] ?? body['message'] ?? 'Falha na requisição.',
      );
    }

    final dataField = body['data'];
    if (dataField is Map) {
      return dataField.cast<String, dynamic>();
    }

    return <String, dynamic>{};
  }

  // ---------------------------------------------------------------------------
  // Dados (titular + dependentes)
  // ---------------------------------------------------------------------------

  /// Busca titular + dependentes.
  ///
  /// Backend: GET /api/v1/carteirinha/dados?idmatricula=<int>
  ///
  /// Retorna um mapa no formato:
  /// {
  ///   "titular": { ... },
  ///   "dependentes": [ ... ]
  /// }
  Future<Map<String, dynamic>> carregarDados({
    required int idMatricula,
  }) async {
    final data = await _getExpectOkData(
      '/carteirinha/dados',
      query: {
        'idmatricula': idMatricula,
      },
    );
    return data;
  }

  // ---------------------------------------------------------------------------
  // Consulta / Emissão
  // ---------------------------------------------------------------------------

  /// Consulta token ativo (se houver) para (matrícula, dependente).
  ///
  /// Backend: POST /api/v1/carteirinha/consultar-ativo
  /// Body: { matricula: <int>, iddependente: <string> }
  ///
  /// Retorna null se:
  /// - não existir token ativo;
  /// - dbToken inválido;
  /// - token já expirado;
  /// - ou se ocorrer qualquer erro de rede/backend.
  Future<CardTokenData?> consultarAtivo({
    required int matricula,
    String iddependente = '0',
  }) async {
    try {
      final data = await _postExpectOkData(
        '/carteirinha/consultar-ativo',
        data: {
          'matricula': matricula,
          'iddependente': iddependente,
        },
      );

      if (data.isEmpty) return null;

      final tokenData = CardTokenData.fromMap(data);

      // dbToken normalizado.
      final int dbTok = tokenData.dbToken ?? 0;
      if (tokenData.token.isEmpty || dbTok <= 0) return null;

      // Se tiver expiração, descarta tokens já vencidos.
      if (tokenData.expiresAtEpoch != null) {
        final left = tokenData.secondsLeft();
        if (left <= 0) return null;
      }

      return tokenData;
    } on DioException catch (e) {
      // Trate 404/rota ausente/sem ativo como “não há” (null).
      if (e.response?.statusCode == 404) return null;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Reaproveita o token ativo; se não houver, emite outro.
  Future<CardTokenData> obterAtivoOuEmitir({
    required int matricula,
    String iddependente = '0',
  }) async {
    final ativo = await consultarAtivo(
      matricula: matricula,
      iddependente: iddependente,
    );
    if (ativo != null) return ativo;
    return emitir(matricula: matricula, iddependente: iddependente);
  }

  /// Emite o token.
  ///
  /// Backend: POST /api/v1/carteirinha/emitir
  /// Body: { matricula: <int>, iddependente: <string> }
  ///
  /// Lança [CarteirinhaException] em caso de erro tratado.
  Future<CardTokenData> emitir({
    required int matricula,
    String iddependente = '0',
  }) async {
    try {
      final res = await api.post<dynamic>(
        '/carteirinha/emitir',
        data: {
          'matricula': matricula,
          'iddependente': iddependente,
        },
      );

      final raw = res.data;
      if (raw is! Map) {
        throw CarteirinhaException(
          code: 'CARD_INVALID_RESPONSE',
          message: 'Resposta inválida da emissão.',
          status: res.statusCode,
        );
      }

      final body = raw.cast<String, dynamic>();

      if (body['ok'] != true) {
        // Pode vir erro estruturado em "error" ou campos soltos.
        if (body['error'] is Map) {
          final err = (body['error'] as Map).cast<String, dynamic>();
          throw CarteirinhaException(
            code: '${err['code'] ?? 'CARD_ISSUE_ERROR'}',
            message: '${err['message'] ?? 'Falha ao emitir.'}',
            details: err['details']?.toString(),
            eid: err['eid']?.toString(),
            status: res.statusCode,
          );
        }

        throw CarteirinhaException(
          code: '${body['code'] ?? 'CARD_ISSUE_ERROR'}',
          message: '${body['message'] ?? 'Falha ao emitir.'}',
          details: body['details']?.toString(),
          eid: body['eid']?.toString(),
          status: res.statusCode,
        );
      }

      final dataField = body['data'];
      if (dataField is! Map) {
        throw CarteirinhaException(
          code: 'CARD_INVALID_RESPONSE',
          message: 'Resposta inválida da emissão.',
          status: res.statusCode,
        );
      }

      return CardTokenData.fromMap(
        dataField.cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      final res = e.response;
      final status = res?.statusCode;

      Map<String, dynamic> errMap = const {};
      if (res?.data is Map) {
        final body = (res!.data as Map).cast<String, dynamic>();
        if (body['error'] is Map) {
          errMap = (body['error'] as Map).cast<String, dynamic>();
        } else if (body['ok'] == false && body['message'] is String) {
          errMap = <String, dynamic>{
            'code': body['code'] ?? 'CARD_ISSUE_ERROR',
            'message': body['message'],
            'details': body['details'],
            'eid': body['eid'],
          };
        }
      }

      String fallbackCode;
      String fallbackMsg;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          fallbackCode = 'TIMEOUT';
          fallbackMsg = 'Tempo de resposta excedido.';
          break;
        case DioExceptionType.connectionError:
          fallbackCode = 'NETWORK';
          fallbackMsg = 'Falha de conexão com o servidor.';
          break;
        case DioExceptionType.badResponse:
          fallbackCode = 'CARD_ISSUE_ERROR';
          fallbackMsg = status == 404
              ? 'Endpoint de emissão indisponível (404).'
              : 'Falha ao emitir.';
          break;
        default:
          fallbackCode = 'CARD_ISSUE_ERROR';
          fallbackMsg = 'Falha ao emitir.';
      }

      throw CarteirinhaException(
        code: '${errMap['code'] ?? fallbackCode}',
        message: '${errMap['message'] ?? fallbackMsg}',
        details: errMap['details']?.toString(),
        eid: errMap['eid']?.toString(),
        status: status,
      );
    } catch (e) {
      throw CarteirinhaException(
        code: 'CARD_ISSUE_ERROR',
        message: 'Erro inesperado ao emitir.',
        details: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Manutenção
  // ---------------------------------------------------------------------------

  /// Agenda o expurgo (202 Accepted quando ok). No-op se dbToken inválido.
  ///
  /// Backend: POST /api/v1/carteirinha/agendar-expurgo
  /// Body: { db_token: <int> }
  Future<void> agendarExpurgo(int? dbToken) async {
    final v = dbToken ?? 0;
    if (v <= 0) return;

    await api.post<dynamic>(
      '/carteirinha/agendar-expurgo',
      data: {
        'db_token': v,
      },
    );
  }

  /// Exclui imediatamente o token (fallback da view ao expirar).
  ///
  /// Aceita db_token OU token simples, conforme o backend.
  ///
  /// Backend: POST /api/v1/carteirinha/excluir-token
  Future<void> excluirToken({int? dbToken, int? token}) async {
    final d = dbToken ?? 0;
    if (d > 0) {
      await api.post<dynamic>(
        '/carteirinha/excluir-token',
        data: {'db_token': d},
      );
      return;
    }

    final t = token ?? 0;
    if (t > 0) {
      await api.post<dynamic>(
        '/carteirinha/excluir-token',
        data: {'token': t},
      );
    }
  }

  /// Alias legado (mantido para compatibilidade).
  Future<void> excluir(int dbToken) => excluirToken(dbToken: dbToken);

  /// Valida o token atual.
  ///
  /// Backend: POST /api/v1/carteirinha/validar
  /// Body: { db_token?: <int>, token?: <int> }
  ///
  /// Retorna diretamente o JSON retornado pelo backend
  /// (tipicamente: { ok, expired, expires_at_ts, ... }).
  Future<Map<String, dynamic>> validar({int? dbToken, int? token}) async {
    final res = await api.post<dynamic>(
      '/carteirinha/validar',
      data: {
        if (dbToken != null) 'db_token': dbToken,
        if (token != null) 'token': token,
      },
    );

    final raw = res.data;
    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      type: DioExceptionType.badResponse,
      error: 'Resposta inválida da validação.',
    );
  }

  /// Consulta o status do agendamento de expurgo.
  ///
  /// Backend: POST /api/v1/carteirinha/agendar-status
  /// Body: { db_token: <int> }
  Future<CardScheduleStatus> statusAgendamento(int dbToken) async {
    final m = await _postExpectOkData(
      '/carteirinha/agendar-status',
      data: {'db_token': dbToken},
    );
    return CardScheduleStatus.fromMap(m);
  }
}

// -----------------------------------------------------------------------------
// Exceção específica da Carteirinha
// -----------------------------------------------------------------------------
class CarteirinhaException implements Exception {
  final String code;
  final String message;
  final String? details;
  final String? eid;
  final int? status;

  CarteirinhaException({
    required this.code,
    required this.message,
    this.details,
    this.eid,
    this.status,
  });

  @override
  String toString() =>
      'CarteirinhaException($code, $message, eid=$eid, status=$status, details=$details)';
}
