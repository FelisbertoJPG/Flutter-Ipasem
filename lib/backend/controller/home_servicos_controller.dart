import 'package:flutter/material.dart';

import '../../common/config/app_config.dart';
import '../../common/models/reimpressao.dart';
import '../../common/repositories/reimpressao_repository.dart';
import '../../common/config/dev_api.dart';
import '../../common/services/session.dart';

class HomeServicosController {
  late final DevApi api;
  late final ReimpressaoRepository reimpRepo;

  HomeServicosController._();

  static Future<HomeServicosController> init(BuildContext context) async {
    final c = HomeServicosController._();
    final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
        ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');
    c.api = DevApi(baseUrl);
    c.reimpRepo = ReimpressaoRepository(c.api);
    return c;
  }

  Future<bool> isLoggedIn() async {
    final p = await Session.getProfile();
    return p != null;
  }

  Future<List<ReimpressaoResumo>> loadHistorico() async {
    final profile = await Session.getProfile();
    if (profile == null) return const [];
    return await reimpRepo.historico(idMatricula: profile.id);
  }

  Future<ReimpressaoDetalhe?> loadDetalhe(int numero) async {
    final profile = await Session.getProfile();
    if (profile == null) return null;
    return await reimpRepo.detalhe(numero, idMatricula: profile.id);
  }

  Future<String?> profileName() async {
    final profile = await Session.getProfile();
    return profile?.nome;
  }
  // HomeServicosController
  Future<bool> waitUntilInHistorico(
      int numero, {
        Duration maxWait = const Duration(seconds: 4),
      }) async {
    final start = DateTime.now();
    var delay = const Duration(milliseconds: 250); // 250ms -> 500 -> 1s -> 2s...

    while (DateTime.now().difference(start) < maxWait) {
      final rows = await loadHistorico();
      if (rows.any((r) => r.numero == numero)) return true;
      await Future.delayed(delay);
      delay *= 2;
    }
    return false;
  }

}
