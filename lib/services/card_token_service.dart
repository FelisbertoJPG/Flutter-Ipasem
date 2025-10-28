// lib/services/card_token_service.dart
import 'dart:math';
import 'package:dio/dio.dart';
import '../models/card_token_models.dart';

class CardTokenService {
  final Dio _dio;
  final Uri _base; // ex.: http://192.9.200.98/api-dev.php

  CardTokenService({
    Dio? dio,
    String? baseUrl,
  })  : _dio = dio ??
      Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        // Não lance exceção automática em 4xx/5xx: vamos ler o corpo e mostrar erro amigável
        validateStatus: (s) => true,
        responseType: ResponseType.json,
        headers: {'Accept': 'application/json'},
      )),
        _base = Uri.parse(
          baseUrl ??
              const String.fromEnvironment(
                'API_BASE',
                defaultValue: 'http://192.9.200.98/api-dev.php',
              ),
        );

  /// RNG seguro de 8 dígitos (1..9 seguido de 7 dígitos 0..9)
  String generateCardToken({int length = 8}) {
    assert(length >= 2);
    final r = Random.secure();
    final b = StringBuffer()..write(r.nextInt(9) + 1);
    for (var i = 1; i < length; i++) b.write(r.nextInt(10));
    return b.toString();
  }

  Future<CardTokenResponse> issueCardToken({
    required int matricula,
    int idDependente = 0,
    bool generateOnClient = true,
    String? clientToken,
    int? ttlOverrideSeconds,
  }) async {
    final suggested = (clientToken?.isNotEmpty == true)
        ? clientToken!
        : (generateOnClient ? generateCardToken(length: 8) : '');

    final Map<String, dynamic> q = <String, dynamic>{
      'action': 'carteirinha_pessoa',
      'matricula': matricula.toString(),
      'iddependente': idDependente.toString(),
      if (suggested.isNotEmpty) 'token': suggested,
      if (ttlOverrideSeconds != null && ttlOverrideSeconds > 0)
        'ttl': ttlOverrideSeconds.toString(),
    };

    final uri = _base.replace(queryParameters: q);

    // LOG útil p/ depurar (use print só em DEV)
    // ignore: avoid_print
    print('[CardTokenService] GET $uri');

    final resp = await _dio.getUri(uri);
    final status = resp.statusCode ?? 0;

    final body = _asMap(resp.data);

    if (status != 200 || body['ok'] == false) {
      final msg = _extractErr(body) ?? 'HTTP $status';
      throw Exception('Falha na emissão: $msg');
    }

    return CardTokenResponse.fromJson(body);
  }

  /// Agenda expurgo após a tela abrir (POST em `schedule_url` ou `action=carteirinha_agendar_expurgo`).
  Future<void> scheduleExpurgo(CardTokenResponse card) async {
    final url = card.scheduleUrl ??
        _base.replace(queryParameters: <String, dynamic>{
          'action': 'carteirinha_agendar_expurgo',
        });

    // Envie como x-www-form-urlencoded de verdade (sem multipart)
    final data = {'db_token': card.dbToken};

    try {
      final resp = await _dio.postUri(
        url,
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final status = resp.statusCode ?? 0;
      if (status != 200) {
        // ignore: avoid_print
        print('[CardTokenService] scheduleExpurgo HTTP $status: ${resp.data}');
      }
    } catch (e) {
      // silencioso em prod; faça log se quiser
      // ignore: avoid_print
      print('[CardTokenService] scheduleExpurgo error: $e');
    }
  }

  Future<CardScheduleStatus?> getScheduleStatus(CardTokenResponse card) async {
    final url = card.scheduleStatusUrl;
    if (url == null) return null;

    final Map<String, String> q = Map<String, String>.from(url.queryParameters);
    q.putIfAbsent('db_token', () => card.dbToken.toString());

    final resp = await _dio.getUri(url.replace(queryParameters: q));
    if ((resp.statusCode ?? 0) != 200) return null;
    final map = _asMap(resp.data);
    return CardScheduleStatus.fromJson(map);
  }

  Future<Map<String, dynamic>> validate(CardTokenResponse card) async {
    final baseUrl = card.validateUrl ??
        _base.replace(queryParameters: <String, dynamic>{
          'action': 'carteirinha_validar',
          'db_token': card.dbToken.toString(),
        });

    final Map<String, String> q = Map<String, String>.from(baseUrl.queryParameters);
    q.putIfAbsent('db_token', () => card.dbToken.toString());

    final resp = await _dio.getUri(baseUrl.replace(queryParameters: q));
    final status = resp.statusCode ?? 0;
    final map = _asMap(resp.data);

    if (status != 200) {
      final msg = _extractErr(map) ?? 'HTTP $status';
      throw Exception('Falha na validação: $msg');
    }
    return map;
  }

  // ---- helpers

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  String? _extractErr(Map<String, dynamic> m) {
    final e = m['error'];
    if (e is Map && e['message'] is String) return e['message'] as String;
    if (m['message'] is String) return m['message'] as String;
    return null;
  }
}
