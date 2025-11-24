// lib/services/banner_app_scraper.dart
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;

/// Um banner lido da página /app-banner/banner-app.
class ScrapedBannerImage {
  final String imageUrl;
  final String? title;

  const ScrapedBannerImage({
    required this.imageUrl,
    this.title,
  });
}

/// Faz o scrape do HTML de /app-banner/banner-app.
class BannerAppScraper {
  final String pageUrl;
  final http.Client _client;

  BannerAppScraper({
    required this.pageUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<List<ScrapedBannerImage>> fetchBanners() async {
    if (pageUrl.isEmpty) return const <ScrapedBannerImage>[];

    final uri = Uri.parse(pageUrl);

    final resp = await _client.get(
      uri,
      headers: const {
        'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'User-Agent': 'IPASEMNH-Digital/1.0 (+banner-app)',
      },
    );

    if (resp.statusCode != 200) {
      throw StateError('HTTP ${resp.statusCode} ao carregar $uri');
    }

    final doc = html.parse(resp.body);

    // Cada card do banner:
    // <div class="card border-0 shadow h-100">
    //   <img class="card-img-top" data-app-src="...">
    //   ...
    // </div>
    final cards = doc.querySelectorAll('div.card.border-0.shadow.h-100');
    if (cards.isEmpty) {
      return const <ScrapedBannerImage>[];
    }

    final result = <ScrapedBannerImage>[];

    for (final card in cards) {
      final dom.Element? img = card.querySelector('img.card-img-top');
      if (img == null) continue;

      final attrs = img.attributes;
      String? src = attrs['data-app-src'] ?? attrs['src'];
      if (src == null || src.trim().isEmpty) continue;
      src = src.trim();

      final dom.Element? titleEl =
          card.querySelector('h5.card-title') ?? card.querySelector('h5');
      final rawTitle = titleEl?.text.trim();
      final String? title =
      (rawTitle == null || rawTitle.isEmpty) ? null : rawTitle;

      result.add(
        ScrapedBannerImage(
          imageUrl: src,
          title: title,
        ),
      );
    }

    return result;
  }
}
