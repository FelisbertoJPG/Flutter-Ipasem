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
      return CardTokenData.fromMap(map);
    } on DioException catch (e) {
      final body = (e.response?.data is Map) ? e.response!.data as Map : const {};
      final err = (body['error'] as Map?) ?? const {};
      throw CarteirinhaException(
        code: '${err['code'] ?? 'CARD_ISSUE_ERROR'}',
        message: '${err['message'] ?? 'Falha ao emitir.'}',
        details: err['details']?.toString(),
        eid: err['eid']?.toString(),
        status: e.response?.statusCode,
      );
    }
  }

  /// Agenda o expurgo (202 Accepted quando ok).
  Future<void> agendarExpurgo(int dbToken) =>
      api.carteirinhaAgendarExpurgo(dbToken: dbToken);

  Future<Map<String, dynamic>> validar({int? dbToken, int? token}) =>
      api.carteirinhaValidar(dbToken: dbToken, token: token);

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
