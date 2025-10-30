// lib/services/carteirinha_service.dart
import 'dart:async';

import 'package:dio/dio.dart';

import '../models/card_token_models.dart';
import 'dev_api.dart';

/// Constrói DevApi aceitando tanto:
/// - API_BASE="http://host/api-dev.php"
/// - API_BASE="http://host" (usa /api-dev.php)
DevApi buildDevApiFromEnv() {
  final raw = const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98/api-dev.php');
  if (raw.endsWith('.php')) {
    final cut = raw.lastIndexOf('/');
    final base = raw.substring(0, cut);
    final path = raw.substring(cut);
    return DevApi(base, apiPath: path);

  }
  return DevApi(raw, apiPath: '/api-dev.php');
}

class CarteirinhaService {
  final DevApi api;

  CarteirinhaService({DevApi? api}) : api = api ?? buildDevApiFromEnv();

  /// Busca titular + dependentes para a tela.
  Future<Map<String, dynamic>> carregarDados({required int idMatricula}) async {
    final data = await this.api.carteirinhaDados(idMatricula: idMatricula);
    return data; // {titular:{...}, dependentes:[...]}
  }

  /// Emite o token (não envia 'token' no payload).
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
      final eid = err['eid'];
      final code = err['code'] ?? 'CARD_ISSUE_ERROR';
      final msg = err['message'] ?? 'Falha ao emitir.';
      final details = err['details'];
      throw CarteirinhaException(
        code: code.toString(),
        message: msg.toString(),
        details: details?.toString(),
        eid: eid?.toString(),
        status: e.response?.statusCode,
      );
    }
  }

  /// Agenda o expurgo. Rota retorna 202 quando aceita.
  Future<void> agendarExpurgo(int dbToken) => api.carteirinhaAgendarExpurgo(dbToken: dbToken);

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
  String toString() => 'CarteirinhaException($code, $message, eid=$eid, status=$status, details=$details)';
}
