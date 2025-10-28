// lib/models/card_token_models.dart
import 'dart:convert';

class CardTokenResponse {
  final String? infoString;
  final String? sexo;
  final String? sexoTxt;

  final String token;
  final int dbToken;

  final String expiresAt;
  final String expiresAtIso;
  final int expiresAtEpoch;
  final int? serverNowEpoch;
  final int ttlSeconds;

  final bool persisted;
  final String? persistSource;

  final Uri? validateUrl;
  final Uri? scheduleUrl;
  final Uri? scheduleStatusUrl;

  CardTokenResponse({
    required this.infoString,
    required this.sexo,
    required this.sexoTxt,
    required this.token,
    required this.dbToken,
    required this.expiresAt,
    required this.expiresAtIso,
    required this.expiresAtEpoch,
    required this.serverNowEpoch,
    required this.ttlSeconds,
    required this.persisted,
    required this.persistSource,
    required this.validateUrl,
    required this.scheduleUrl,
    required this.scheduleStatusUrl,
  });

  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= expiresAtEpoch;
  }

  Duration get remaining {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final left = (expiresAtEpoch - now);
    return Duration(seconds: left.clamp(0, 1 << 31));
  }

  factory CardTokenResponse.fromJson(Map<String, dynamic> json) {
    final map = (json.containsKey('data') && json['data'] is Map<String, dynamic>)
        ? (json['data'] as Map<String, dynamic>)
        : json;

    Uri? _u(String? s) => (s == null || s.isEmpty) ? null : Uri.tryParse(s);

    final dbTok = (map['db_token'] ?? map['token']);
    return CardTokenResponse(
      infoString: map['string'] as String?,
      sexo: map['sexo']?.toString(),
      sexoTxt: map['sexo_txt']?.toString(),
      token: map['token']?.toString() ?? '',
      dbToken: int.tryParse('${dbTok ?? 0}') ?? 0,
      expiresAt: map['expires_at']?.toString() ?? '',
      expiresAtIso: map['expires_at_iso']?.toString() ?? '',
      expiresAtEpoch: (map['expires_at_epoch'] is int)
          ? map['expires_at_epoch'] as int
          : int.tryParse('${map['expires_at_epoch'] ?? 0}') ?? 0,
      serverNowEpoch: (map['server_now_epoch'] is int)
          ? map['server_now_epoch'] as int
          : (map['server_now_epoch'] != null ? int.tryParse('${map['server_now_epoch']}') : null),
      ttlSeconds: (map['ttl_seconds'] is int)
          ? map['ttl_seconds'] as int
          : int.tryParse('${map['ttl_seconds'] ?? 0}') ?? 0,
      persisted: map['persisted'] == true,
      persistSource: map['persist_source']?.toString(),
      validateUrl: _u(map['validate_url']?.toString()),
      scheduleUrl: _u(map['schedule_url']?.toString()),
      scheduleStatusUrl: _u(map['schedule_status_url']?.toString()),
    );
  }

  @override
  String toString() => jsonEncode({
    'string': infoString,
    'sexo': sexo,
    'sexo_txt': sexoTxt,
    'token': token,
    'db_token': dbToken,
    'expires_at': expiresAt,
    'expires_at_iso': expiresAtIso,
    'expires_at_epoch': expiresAtEpoch,
    'server_now_epoch': serverNowEpoch,
    'ttl_seconds': ttlSeconds,
    'persisted': persisted,
    'persist_source': persistSource,
    'validate_url': validateUrl?.toString(),
    'schedule_url': scheduleUrl?.toString(),
    'schedule_status_url': scheduleStatusUrl?.toString(),
  });
}

class CardScheduleStatus {
  final String? state;
  final String? result;
  final int? expTs;
  final int? serverNow;
  final bool? dbExists;
  final String? eid;

  CardScheduleStatus({
    this.state,
    this.result,
    this.expTs,
    this.serverNow,
    this.dbExists,
    this.eid,
  });

  factory CardScheduleStatus.fromJson(Map<String, dynamic> json) => CardScheduleStatus(
    state: json['state']?.toString(),
    result: json['result']?.toString(),
    expTs: (json['exp_ts'] is int) ? json['exp_ts'] as int : int.tryParse('${json['exp_ts'] ?? ''}'),
    serverNow:
    (json['server_now'] is int) ? json['server_now'] as int : int.tryParse('${json['server_now'] ?? ''}'),
    dbExists: json['db_exists'] is bool ? json['db_exists'] as bool : null,
    eid: json['eid']?.toString(),
  );
}
