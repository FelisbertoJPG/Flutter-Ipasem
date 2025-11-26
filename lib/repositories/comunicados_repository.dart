// lib/repositories/comunicados_repository.dart
import 'dart:async';

import '../core/models.dart' show ComunicadoResumo;
import '../api/cards_page_scraper.dart';

class ComunicadosRepository {
  final CardsPageScraper _scraper;

  ComunicadosRepository([CardsPageScraper? scraper])
      : _scraper = scraper ??
      const CardsPageScraper(
        pageUrl:
        'https://www.ipasemnh.com.br/comunicacao-app/cards',
      );

  /// Lê a página HTML dos cards e converte para ComunicadoResumo.
  Future<List<ComunicadoResumo>> listPublicados({
    int limit = 6,
    String? categoria,
    String? q, // usa-se como 'tag' opcional na URL (o HTML já filtra no servidor, se implementado)
  }) async {
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
          : _firstLines(_stripHtml(c.corpoHtml ?? ''), 160);

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
