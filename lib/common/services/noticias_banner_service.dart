// lib/services/banner_app_scraper.dart
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;

/// Um banner extraído da página /app-banner/banner-app.
class ScrapedBannerImage {
  final String src;   // URL absoluta da imagem
  final String? href; // link clicável (se a imagem estiver dentro de <a>)
  final String? alt;  // texto alternativo, se houver

  const ScrapedBannerImage({
    required this.src,
    this.href,
    this.alt,
  });
}

/// Faz scrape da página HTML do banner-app (não usa JSON).
class BannerAppScraper {
  final String pageUrl;

  const BannerAppScraper(this.pageUrl);

  Future<List<ScrapedBannerImage>> fetch({int limit = 3}) async {
    if (pageUrl.isEmpty) {
      return const <ScrapedBannerImage>[];
    }

    final uri = Uri.parse(pageUrl);

    final resp = await http.get(
      uri,
      headers: const {
        // força HTML, igual ao CardsPageScraper
        'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'User-Agent': 'IPASEM-App/1.0',
      },
    );

    if (resp.statusCode != 200) {
      throw StateError('HTTP ${resp.statusCode} ao carregar $uri');
    }

    final document = html.parse(resp.body);
    final body = document.body;
    if (body == null) {
      return const <ScrapedBannerImage>[];
    }

    // Pega todos os <img> do body (se depois quiser filtrar por classe, ajusta aqui).
    final imgNodes = body.querySelectorAll('img');
    if (imgNodes.isEmpty) {
      return const <ScrapedBannerImage>[];
    }

    final out = <ScrapedBannerImage>[];

    for (final img in imgNodes) {
      final rawSrc = img.attributes['src']?.trim();
      if (rawSrc == null || rawSrc.isEmpty) continue;

      final src = _resolveUrl(uri, rawSrc);

      // Se estiver dentro de <a>, pega o href para eventual clique.
      final dom.Element? link = img.closest('a');
      final rawHref = link?.attributes['href']?.trim();
      final href = (rawHref != null && rawHref.isNotEmpty)
          ? _resolveUrl(uri, rawHref)
          : null;

      final alt = img.attributes['alt']?.trim();

      out.add(ScrapedBannerImage(
        src: src,
        href: href,
        alt: alt,
      ));

      if (limit > 0 && out.length >= limit) break;
    }

    return out;
  }

  /// Normaliza URL relativa para absoluta, com base na URL da página.
  String _resolveUrl(Uri base, String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    if (raw.startsWith('//')) {
      return '${base.scheme}:$raw';
    }

    if (raw.startsWith('/')) {
      final origin =
          '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
      return '$origin$raw';
    }

    // caminho relativo qualquer
    return base.resolve(raw).toString();
  }
}

extension on dom.Element {
  dom.Element? closest(String s) {}
}
