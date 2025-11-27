// lib/models/card_token_models.dart
import 'dart:convert';

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  if (v is bool) return v ? 1 : 0;
  return null;
}

/// Normaliza timestamps para **segundos**.
/// Se vier em ms (muito grande), converte para s.
int? _asEpochSec(dynamic v) {
  final n = _asInt(v);
  if (n == null) return null;
  return (n > 20000000000) ? (n ~/ 1000) : n;
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    return s == '1' || s == 'true' || s == 'yes' || s == 'y' || s == 'on';
  }
  return false;
}

class CardTokenData {
  final String? prettyString;              // "string" legível para copiar
  final String? sexo;                      // "M"/"F"/null
  final String? sexoTxt;                   // "Masculino"/"Feminino"/"Não informado"
  final String token;                      // sempre texto no backend
  final int? dbToken;                      // inteiro (pode ser null se backend não persistiu)
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
    this.dbToken,
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
    final dbTok = _asInt(m['db_token']) ?? _asInt(m['token']);
    return CardTokenData(
      prettyString: m['string'] as String?,
      sexo: m['sexo'] as String?,
      sexoTxt: m['sexo_txt'] as String?,
      token: (m['token'] ?? '').toString(),
      dbToken: dbTok,
      expiresAt: m['expires_at'] as String?,
      expiresAtIso: m['expires_at_iso'] as String?,
      expiresAtEpoch: _asEpochSec(m['expires_at_epoch']),
      serverNowEpoch: _asEpochSec(m['server_now_epoch']),
      ttlSeconds: _asInt(m['ttl_seconds']),
      persisted: _asBool(m['persisted']),
      persistSource: m['persist_source'] as String?,
      validateUrl: m['validate_url'] as String?,
      scheduleUrl: m['schedule_url'] as String?,
      scheduleStatusUrl: m['schedule_status_url'] as String?,
    );
  }

  static CardTokenData fromJson(String s) =>
      CardTokenData.fromMap(json.decode(s) as Map<String, dynamic>);

  /// Segundos restantes considerando o relógio do servidor como base (se disponível).
  /// Já presume que `expiresAtEpoch` e `serverNowEpoch` estão normalizados em segundos.
  int secondsLeft({int? clientNowEpoch}) {
    final nowSec = clientNowEpoch ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final baseNow = serverNowEpoch ?? nowSec;
    final exp = expiresAtEpoch;
    if (exp == null) return 0;
    final delta = exp - baseNow;
    return delta > 0 ? delta : 0;
  }
}

class CardScheduleStatus {
  final bool scheduled;
  final bool duplicate;
  final bool dbExists;
  final int? expTsDb;     // epoch s
  final int serverNow;    // epoch s

  CardScheduleStatus({
    required this.scheduled,
    required this.duplicate,
    required this.dbExists,
    required this.serverNow,
    this.expTsDb,
  });

  factory CardScheduleStatus.fromMap(Map<String, dynamic> m) => CardScheduleStatus(
    scheduled: _asBool(m['scheduled'] ?? m['ok']),
    duplicate: _asBool(m['duplicate']),
    dbExists: _asBool(m['db_exists']),
    serverNow: _asEpochSec(m['server_now']) ?? 0,
    expTsDb: _asEpochSec(m['exp_ts_db']),
  );
}
