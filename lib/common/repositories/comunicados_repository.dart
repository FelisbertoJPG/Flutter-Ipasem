// lib/repositories/comunicados_repository.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../backend/models/models.dart' show ComunicadoResumo;
import '../api/cards_page_scraper.dart';

class ComunicadosRepository {
  final CardsPageScraper _scraper;

  /// Construtor legado: usa a URL de produção por padrão.
  ComunicadosRepository([CardsPageScraper? scraper])
      : _scraper = scraper ??
      const CardsPageScraper(
        pageUrl:
        'https://www.ipasemnh.com.br/comunicacao-app/cards',
      );

  /// Novo: monta a URL de /comunicacao-app/cards a partir do baseApiUrl
  /// (funciona tanto em 98 quanto em produção).
  factory ComunicadosRepository.fromBaseApi(String baseApiUrl) {
    final cardsUrl = buildComunicadosCardsUrlFromBase(baseApiUrl);
    if (kDebugMode) {
      debugPrint(
        '[ComunicadosRepository] baseApi=$baseApiUrl → cardsUrl=$cardsUrl',
      );
    }
    return ComunicadosRepository(
      CardsPageScraper(pageUrl: cardsUrl),
    );
  }

  /// Lê a página HTML dos cards e converte para ComunicadoResumo.
  Future<List<ComunicadoResumo>> listPublicados({
    int limit = 6,
    String? categoria,
    String? q, // mapeado para 'tag' na URL
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[ComunicadosRepository] listPublicados(limit=$limit, categoria=$categoria, q=$q)',
      );
    }

    final rows = await _scraper.fetch(
      limit: limit,
      categoria: categoria,
      tag: q,
    );

    // Mapeia para o view-model leve da UI.
    return rows.map((c) {
      final descricao =
      (c.resumo != null && c.resumo!.trim().isNotEmpty)
          ? c.resumo!.trim()
          : _firstLines(
        _stripHtml(c.corpoHtml ?? ''),
        160,
      );

      return ComunicadoResumo(
        id: 0, // não há ID disponível no HTML dos cards
        titulo: c.titulo,
        descricao: descricao.isEmpty ? null : descricao,
        data: c.publicadoEm,
      );
    }).toList(growable: false);
  }

  /// Alias compatível com código antigo.
  Future<List<ComunicadoResumo>> fetchResumos({int limit = 6}) {
    return listPublicados(limit: limit);
  }

  // Helpers
  static String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _firstLines(String s, int max) {
    if (s.length <= max) return s;
    return s.substring(0, max).trimRight() + '…';
  }
}
