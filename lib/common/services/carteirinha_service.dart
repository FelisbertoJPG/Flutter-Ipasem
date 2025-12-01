// lib/services/carteirinha_service.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../models/card_token.dart';
import 'api_router.dart';
import 'dev_api.dart';

class CarteirinhaService {
  final DevApi api;

  /// Preferir quando há BuildContext (usa AppConfig do main ativo).
  CarteirinhaService.fromContext(BuildContext context)
      : api = ApiRouter.fromContext(context);

  /// Útil em camadas sem contexto; usa env/API_BASE (fallback PROD).
  CarteirinhaService({DevApi? api}) : api = api ?? ApiRouter.client();

  /// Busca titular + dependentes.
  ///
  /// Retorna um mapa no formato:
  /// {
  ///   "titular": { ... },
  ///   "dependentes": [ ... ]
  /// }
  Future<Map<String, dynamic>> carregarDados({
    required int idMatricula,
  }) async {
    final data = await api.carteirinhaDados(idMatricula: idMatricula);
    return data;
  }

  // ---------------------------------------------------------------------------
  // Consulta / Emissão
  // ---------------------------------------------------------------------------

  /// Consulta token ativo (se houver) para (matrícula, dependente).
  ///
  /// Retorna null se:
  /// - não existir token ativo;
  /// - dbToken inválido;
  /// - token já expirado.
  Future<CardTokenData?> consultarAtivo({
    required int matricula,
    String iddependente = '0',
  }) async {
    try {
      final map = await api.carteirinhaConsultarAtivo(
        matricula: matricula,
        iddependente: iddependente,
      );
      if (map is! Map<String, dynamic>) return null;

      final data = CardTokenData.fromMap(map);

      // dbToken normalizado.
      final int dbTok = data.dbToken ?? 0;
      if (data.token.isEmpty || dbTok <= 0) return null;

      // Se tiver expiração, descarta tokens já vencidos.
      if (data.expiresAtEpoch != null) {
        final left = data.secondsLeft();
        if (left <= 0) return null;
      }

      return data;
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

  /// Emite o token (rota mapeada no gateway).
  ///
  /// Lança [CarteirinhaException] em caso de erro tratado
  /// e deixa qualquer erro inesperado encapsulado também em [CarteirinhaException].
  Future<CardTokenData> emitir({
    required int matricula,
    String iddependente = '0',
  }) async {
    try {
      final map = await api.carteirinhaEmitir(
        matricula: matricula,
        iddependente: iddependente,
      );

      // Validação leve do envelope antes do parse.
      if (map is! Map<String, dynamic>) {
        throw CarteirinhaException(
          code: 'CARD_INVALID_RESPONSE',
          message: 'Resposta inválida da emissão.',
          status: 200,
        );
      }

      return CardTokenData.fromMap(map);
    } on DioException catch (e) {
      final res = e.response;
      final status = res?.statusCode;

      Map<String, dynamic> errMap = const {};
      if (res?.data is Map) {
        final body = (res!.data as Map).cast<String, dynamic>();
        if (body['error'] is Map) {
          errMap = (body['error'] as Map).cast<String, dynamic>();
        } else if (body['ok'] == false && body['message'] is String) {
          errMap = {
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
          fallbackMsg =
          status == 404 ? 'Endpoint de emissão indisponível (404).' : 'Falha ao emitir.';
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
  Future<void> agendarExpurgo(int? dbToken) async {
    final v = dbToken ?? 0;
    if (v <= 0) return;
    await api.carteirinhaAgendarExpurgo(dbToken: v);
  }

  /// Exclui imediatamente o token (fallback da view ao expirar).
  ///
  /// Aceita db_token OU token simples, conforme o gateway.
  Future<void> excluirToken({int? dbToken, int? token}) async {
    final d = dbToken ?? 0;
    if (d > 0) {
      await api.carteirinhaExcluir(dbToken: d);
      return;
    }

    final t = token ?? 0;
    if (t > 0) {
      // Se o gateway aceitar "token" puro, troque por api.carteirinhaExcluirToken(token: t)
      await api.carteirinhaExcluir(dbToken: t);
    }
  }

  /// Alias legado (mantido para compatibilidade).
  Future<void> excluir(int dbToken) => excluirToken(dbToken: dbToken);

  /// Valida o token atual (tipicamente: {expired: bool, expires_at_ts: int}).
  Future<Map<String, dynamic>> validar({int? dbToken, int? token}) =>
      api.carteirinhaValidar(dbToken: dbToken, token: token);

  /// Consulta o status do agendamento de expurgo.
  Future<CardScheduleStatus> statusAgendamento(int dbToken) async {
    final m = await api.carteirinhaAgendarStatus(dbToken: dbToken);
    return CardScheduleStatus.fromMap(m);
  }
}

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
