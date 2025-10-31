// lib/services/polling/exame_status_poller.dart
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../services/dev_api.dart';
import '../../services/session.dart';
import '../../state/auth_events.dart';
import '../../ui/components/app_alert.dart';
import 'package:flutter/widgets.dart';

class ExameStatusChangedEvent {
  final int numero;
  final String novoStatus;    // 'A' (liberada) | 'I' (negada) | 'P' etc.
  final String? antigoStatus; // opcional
  ExameStatusChangedEvent({
    required this.numero,
    required this.novoStatus,
    this.antigoStatus,
  });
}

class ExameStatusPoller {
  final DevApi api;
  final Duration interval;
  final BuildContext Function()? contextProvider; // onde mostrar toast (opcional)

  Timer? _timer;
  bool _busy = false;
  Map<int, String> _cache = {}; // numero -> status

  ExameStatusPoller({
    required this.api,
    this.interval = const Duration(seconds: 30), //duração
    this.contextProvider,
  });

  Future<void> start() async {
    await _loadCache();
    await pollNow();
    _timer ??= Timer.periodic(interval, (_) => _safePoll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> pollNow() => _safePoll();

  Future<void> _safePoll() async {
    if (_busy) return;
    _busy = true;
    try {
      final profile = await Session.getProfile();
      if (profile == null) return;

      final res = await api.postAction('exames_historico', data: {
        'id_matricula': profile.id,
      });

      final body = (res.data as Map?) ?? const {};
      if (body['ok'] != true) return;

      final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];
      final current = <int, String>{};
      for (final r in rows) {
        final m = (r as Map);
        final num = int.tryParse('${m['nro_autorizacao'] ?? m['numero'] ?? 0}') ?? 0;
        if (num <= 0) continue;
        final st = (m['auditado'] ?? '').toString().trim().toUpperCase();
        current[num] = st;
      }

      // detecta mudanças relevantes (P->A ou P->I, etc)
      final changes = <ExameStatusChangedEvent>[];
      current.forEach((num, st) {
        final prev = _cache[num];
        if (prev != null && prev != st && (st == 'A' || st == 'I')) {
          changes.add(ExameStatusChangedEvent(
            numero: num,
            novoStatus: st,
            antigoStatus: prev,
          ));
        }
      });

      if (changes.isNotEmpty) {
        // dispara evento global + toast
        final ctx = contextProvider?.call();
        for (final c in changes) {
          AuthEvents.instance.emitStatusChanged(c.numero, c.novoStatus);
          if (ctx != null) {
            final msg = c.novoStatus == 'A'
                ? 'Autorização #${c.numero} liberada.'
                : 'Autorização #${c.numero} negada.';
            AppAlert.toast(ctx, msg);
          }
        }
      }

      _cache = current;
      await _saveCache();
    } catch (_) {
      // silencioso: não queremos travar o app por causa do polling
    } finally {
      _busy = false;
    }
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('exames_status_cache') ?? '{}';
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _cache = {
        for (final e in map.entries)
          int.parse(e.key): (e.value as String).toUpperCase()
      };
    } catch (_) {
      _cache = {};
    }
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final enc = jsonEncode(_cache.map((k, v) => MapEntry(k.toString(), v)));
    await prefs.setString('exames_status_cache', enc);
  }
}
