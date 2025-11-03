// lib/services/carteirinha_service.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../models/card_token_models.dart';
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
  Future<Map<String, dynamic>> carregarDados({required int idMatricula}) async {
    final data = await api.carteirinhaDados(idMatricula: idMatricula);
    return data; // {titular:{...}, dependentes:[...]}
  }

  /// Emite o token (rota mapeada no gateway).
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
      // Normaliza payloads variados (ok=false / error={} / outras formas).
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

      // Classificação por tipo de falha de rede/timeout.
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
      // Protege contra erros de parsing/conversão inesperados.
      throw CarteirinhaException(
        code: 'CARD_ISSUE_ERROR',
        message: 'Erro inesperado ao emitir.',
        details: e.toString(),
      );
    }
  }

  /// Agenda o expurgo (202 Accepted quando ok).
  Future<void> agendarExpurgo(int dbToken) =>
      api.carteirinhaAgendarExpurgo(dbToken: dbToken);

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
