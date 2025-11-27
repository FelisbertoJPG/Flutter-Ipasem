// lib/services/polling/exame_bg_worker.dart
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dev_api.dart';      // estava ../services/dev_api.dart
import '../session.dart';     // estava ../services/session.dart
import '../notifier.dart';    // estava ../services/notifier.dart

const kExameBgUniqueName = 'exameStatusPoll';

@pragma('vm:entry-point')
void exameBgDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      // 1) Notificações prontas no isolate de background
      await AppNotifier.I.init(); // precisa ser idempotente

      // 2) API base — sem BuildContext, usa env var com fallback
      final baseUrl = const String.fromEnvironment(
        'API_BASE',
        defaultValue: 'https://assistweb.ipasemnh.com.br',
      );
      final api = DevApi(baseUrl);

      // 3) precisa estar logado (profile salvo)
      final profile = await Session.getProfile();
      if (profile == null) return true;

      // 4) chama histórico
      final res = await api.postAction('exames_historico', data: {
        'id_matricula': profile.id,
      });
      final body = (res.data as Map?) ?? const {};
      if (body['ok'] != true) return true;

      final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];
      final current = <int, String>{};
      for (final r in rows) {
        final m = (r as Map);
        final num = int.tryParse('${m['nro_autorizacao'] ?? m['numero'] ?? 0}') ?? 0;
        if (num <= 0) continue;
        final st = (m['auditado'] ?? '').toString().trim().toUpperCase();
        current[num] = st;
      }

      // 5) cache antigo
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('exames_status_cache') ?? '{}';
      Map<int, String> old = {};
      try {
        final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
        old = {
          for (final e in map.entries) int.parse(e.key): (e.value as String).toUpperCase()
        };
      } catch (_) {}

      // 6) detectar mudanças relevantes e notificar
      for (final e in current.entries) {
        final prev = old[e.key];
        final now  = e.value;
        if (prev != null && prev != now && (now == 'A' || now == 'I')) {
          if (now == 'A') {
            await AppNotifier.I.notifyExameLiberado(numero: e.key);
          } else {
            await AppNotifier.I.showSimple(
              title: 'Autorização negada',
              body: 'Autorização #${e.key} foi negada.',
            );
          }
        }
      }

      // 7) grava cache novo
      final enc = jsonEncode(current.map((k, v) => MapEntry(k.toString(), v)));
      await prefs.setString('exames_status_cache', enc);
    } catch (_) {
      // silencioso — não queremos crashar o worker
    }

    return true; // sinaliza “feito”
  });
}
