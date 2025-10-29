// lib/models/card_token_models.dart
import 'dart:convert';

class CardTokenData {
  final String? prettyString;              // "string" legível para copiar
  final String? sexo;                      // "M"/"F"/null
  final String? sexoTxt;                   // "Masculino"/"Feminino"/"Não informado"
  final String token;                      // sempre texto no backend
  final int dbToken;                       // inteiro (padrão: igual ao token)
  final String? expiresAt;                 // "YYYY-MM-DD HH:mm:ss"
  final String? expiresAtIso;              // ISO-8601 com TZ
  final int? expiresAtEpoch;               // epoch segundos
  final int? serverNowEpoch;               // epoch segundos (lado servidor)
  final int? ttlSeconds;                   // TTL concedido
  final bool persisted;                    // true quando gravado no DB
  final String? persistSource;             // "db" | "session" | ...
  final String? validateUrl;
  final String? scheduleUrl;
  final String? scheduleStatusUrl;
  String? get string => prettyString;

  CardTokenData({
    required this.token,
    required this.dbToken,
    this.prettyString,
    this.sexo,
    this.sexoTxt,
    this.expiresAt,
    this.expiresAtIso,
    this.expiresAtEpoch,
    this.serverNowEpoch,
    this.ttlSeconds,
    this.persisted = false,
    this.persistSource,
    this.validateUrl,
    this.scheduleUrl,
    this.scheduleStatusUrl,
  });

  factory CardTokenData.fromMap(Map<String, dynamic> m) {
    return CardTokenData(
      prettyString: m['string'] as String?,
      sexo: m['sexo'] as String?,
      sexoTxt: m['sexo_txt'] as String?,
      token: (m['token'] ?? '').toString(),
      dbToken: (m['db_token'] is String)
          ? int.tryParse(m['db_token']) ?? 0
          : (m['db_token'] ?? 0) as int,
      expiresAt: m['expires_at'] as String?,
      expiresAtIso: m['expires_at_iso'] as String?,
      expiresAtEpoch: (m['expires_at_epoch'] is String)
          ? int.tryParse(m['expires_at_epoch'])
          : m['expires_at_epoch'] as int?,
      serverNowEpoch: (m['server_now_epoch'] is String)
          ? int.tryParse(m['server_now_epoch'])
          : m['server_now_epoch'] as int?,
      ttlSeconds: (m['ttl_seconds'] is String)
          ? int.tryParse(m['ttl_seconds'])
          : m['ttl_seconds'] as int?,
      persisted: (m['persisted'] ?? false) as bool,
      persistSource: m['persist_source'] as String?,
      validateUrl: m['validate_url'] as String?,
      scheduleUrl: m['schedule_url'] as String?,
      scheduleStatusUrl: m['schedule_status_url'] as String?,
    );
  }

  static CardTokenData fromJson(String s) =>
      CardTokenData.fromMap(json.decode(s) as Map<String, dynamic>);

  /// Segundos restantes considerando o relógio do servidor como base (se disponível).
  int secondsLeft({int? clientNowEpoch}) {
    final now = clientNowEpoch ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final serverNow = serverNowEpoch;
    final exp = expiresAtEpoch;
    if (exp == null) return 0;
    final baseNow = serverNow ?? now;
    final delta = exp - baseNow;
    return delta < 0 ? 0 : delta;
  }
}

class CardScheduleStatus {
  final bool scheduled;
  final bool duplicate;
  final bool dbExists;
  final int? expTsDb;
  final int serverNow;

  CardScheduleStatus({
    required this.scheduled,
    required this.duplicate,
    required this.dbExists,
    required this.serverNow,
    this.expTsDb,
  });

  factory CardScheduleStatus.fromMap(Map<String, dynamic> m) => CardScheduleStatus(
    scheduled: (m['scheduled'] ?? m['ok'] ?? false) as bool,
    duplicate: (m['duplicate'] ?? false) as bool,
    dbExists: (m['db_exists'] ?? false) as bool,
    serverNow: (m['server_now'] ?? 0) as int,
    expTsDb: m['exp_ts_db'] as int?,
  );
}
