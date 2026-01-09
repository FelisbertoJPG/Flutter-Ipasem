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
        pageUrl: 'https://www.ipasemnh.com.br/comunicacao-app/cards',
      );

  /// Novo: monta a URL de /comunicacao-app/cards a partir do baseApiUrl
  /// (funciona tanto em 98 quanto em produção).
  ///
  /// Mesmo assim, se essa URL der erro em tempo de execução,
  /// o método listPublicados() faz fallback para a URL fixa de produção.
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

    final hasFilters = categoria != null || q != null;

    List rows;

    // 1) Tenta usar o scraper configurado (derivado do baseApiUrl)
    try {
      rows = await _scraper.fetch(
        limit: limit,
        categoria: categoria,
        tag: q,
      );
    } catch (e) {
      // Se der erro de rede/URL, cai para a URL fixa oficial
      if (kDebugMode) {
        debugPrint(
          '[ComunicadosRepository] erro ao buscar comunicados na URL do ambiente ($e); '
              'fazendo fallback para https://www.ipasemnh.com.br/comunicacao-app/cards',
        );
      }

      const fallbackScraper = CardsPageScraper(
        pageUrl: 'https://www.ipasemnh.com.br/comunicacao-app/cards',
      );
      rows = await fallbackScraper.fetch(limit: limit);

      // Nesse cenário, já usamos a URL boa, então mapeamos direto.
      return _mapRows(rows);
    }

    // 2) Se vier vazio *e* havia filtros (categoria/tag), tenta novamente sem filtros.
    if (rows.isEmpty && hasFilters) {
      if (kDebugMode) {
        debugPrint(
          '[ComunicadosRepository] nenhum comunicado com os filtros (categoria/tag); '
              'tentando novamente sem filtros.',
        );
      }

      try {
        final withoutFilters = await _scraper.fetch(limit: limit);
        if (withoutFilters.isNotEmpty) {
          rows = withoutFilters;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[ComunicadosRepository] erro ao buscar comunicados sem filtros ($e). '
                'Mantendo resultado vazio.',
          );
        }
      }
    }

    return _mapRows(rows);
  }

  /// Alias compatível com código antigo.
  Future<List<ComunicadoResumo>> fetchResumos({int limit = 6}) {
    return listPublicados(limit: limit);
  }

  // === Helpers internos ===

  List<ComunicadoResumo> _mapRows(List rows) {
    return rows.map<ComunicadoResumo>((c) {
      final descricao = (c.resumo != null && c.resumo!.trim().isNotEmpty)
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

  static String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _firstLines(String s, int max) {
    if (s.length <= max) return s;
    return s.substring(0, max).trimRight() + '…';
  }
}
