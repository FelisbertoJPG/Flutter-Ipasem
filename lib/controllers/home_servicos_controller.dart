import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/dev_api.dart';
import '../services/session.dart';
import '../repositories/reimpressao_repository.dart';
import '../models/reimpressao.dart';

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
}
