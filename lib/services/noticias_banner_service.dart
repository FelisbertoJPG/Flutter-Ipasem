// lib/services/noticias_banner_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

import '../models/noticia_banner.dart';

/// Serviço para obter as notícias em destaque para o banner.
/// - Se `feedUrl` retornar JSON, interpreta como API.
/// - Caso contrário, faz scraping do HTML (cenário servidor 125 /materias).
class NoticiasBannerService {
  final String feedUrl;

  const NoticiasBannerService({required this.feedUrl});

  Future<List<NoticiaBanner>> listarUltimas({int limit = 3}) async {
    final url = feedUrl.trim();
    if (url.isEmpty) return const <NoticiaBanner>[];

    final uri = Uri.parse(url);
    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      return const <NoticiaBanner>[];
    }

    final body = resp.body;
    final trimmed = body.trimLeft();

    // 1) Tenta tratar como JSON (cenário MyAdmin / API nova)
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = json.decode(body);
        return _fromJson(decoded, limit: limit);
      } catch (_) {
        // Se falhar, cai para parsing de HTML.
      }
    }

    // 2) Fallback: scraping de HTML de /materias
    return _fromHtml(body, baseUri: uri, limit: limit);
  }

  // --------- Parsing JSON genérico ---------

  List<NoticiaBanner> _fromJson(dynamic decoded, {required int limit}) {
    final List<NoticiaBanner> out = [];

    // Possíveis formatos:
    // - [{...}, {...}]
    // - { ok: true, data: { rows: [...] } }
    // - { rows: [...] }
    List<dynamic> rowsDynamic = const [];

    if (decoded is List) {
      rowsDynamic = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final root = decoded;
      if (root['data'] is Map<String, dynamic>) {
        final data = root['data'] as Map<String, dynamic>;
        if (data['rows'] is List) {
          rowsDynamic = data['rows'] as List;
        }
      } else if (root['rows'] is List) {
        rowsDynamic = root['rows'] as List;
      }
    }

    for (final row in rowsDynamic) {
      if (row is Map) {
        final map = row.cast<String, dynamic>();
        out.add(NoticiaBanner.fromApi(map));
        if (out.length >= limit) break;
      }
    }

    return out;
  }

  // --------- Scraping HTML de /materias ---------

  List<NoticiaBanner> _fromHtml(
      String html, {
        required Uri baseUri,
        required int limit,
      }) {
    final doc = html_parser.parse(html);

    // Os cards de notícias estão dentro do <section ...> com class row...
    // Vamos pegar todos os .card dentro desse section.
    final section = doc.querySelector('section');
    if (section == null) return const <NoticiaBanner>[];

    final cards = section.querySelectorAll('.card');
    if (cards.isEmpty) return const <NoticiaBanner>[];

    final List<NoticiaBanner> result = [];

    for (final card in cards) {
      final banner = _parseCard(card, baseUri);
      if (banner != null) {
        result.add(banner);
        if (result.length >= limit) break;
      }
    }

    return result;
  }

  NoticiaBanner? _parseCard(dom.Element card, Uri baseUri) {
    // Imagem principal -> <img class="img-card" src="...">
    final img = card.querySelector('img.img-card');
    final rawImgSrc = img?.attributes['src']?.trim();
    if (rawImgSrc == null || rawImgSrc.isEmpty) return null;
    final imagemUrl = _normalizeUrl(rawImgSrc, baseUri);

    // Título -> <span class="title">...</span>
    final titleEl =
        card.querySelector('.content .title') ?? card.querySelector('.title');
    final titulo = titleEl?.text.trim();
    if (titulo == null || titulo.isEmpty) return null;

    // Data -> <p class="data">...</p> com algo como "21/11/2025"
    final dataEl =
        card.querySelector('.content .data') ?? card.querySelector('.data');
    final dataText = dataEl?.text.trim();
    final data = _parseBrDate(dataText);

    // URL de detalhe: vem do onclick do botão dentro de .buttons:
    // onclick="window.location.href='/materias/noticia?titulo=...&id=123'"
    String? linkUrl;
    int id = 0;

    final btn = card.querySelector('.buttons button');
    final onclick = btn?.attributes['onclick'];

    if (onclick != null && onclick.contains("window.location.href")) {
      const marker = "window.location.href='";
      final idx = onclick.indexOf(marker);
      if (idx >= 0) {
        final start = idx + marker.length;
        final end = onclick.indexOf("'", start);
        if (end > start) {
          final rawHref = onclick.substring(start, end);
          linkUrl = _normalizeUrl(rawHref, baseUri);
          id = _extractIdFromUrl(linkUrl) ?? 0;
        }
      }
    }

    return NoticiaBanner(
      id: id,
      titulo: titulo,
      resumo: null, // banner pode mostrar só o título, resumo é opcional
      imagemUrl: imagemUrl,
      linkUrl: linkUrl,
      data: data,
      raw: null,
    );
  }

  // --------- Utilidades ---------

  /// Normaliza URLs relativas usando a base (ex.: /materias/noticia → https://dominio/materias/noticia).
  String _normalizeUrl(String url, Uri base) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return '${base.scheme}:$trimmed';
    }

    // Relativo ao host
    return base.resolve(trimmed).toString();
  }

  /// Extrai "id" da query string (?id=123) se existir.
  int? _extractIdFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final idStr = uri.queryParameters['id'];
    if (idStr == null) return null;
    return int.tryParse(idStr);
  }

  /// Faz parse de datas no formato "dd/MM/yyyy" que aparecem na view PHP.
  DateTime? _parseBrDate(String? txt) {
    if (txt == null || txt.isEmpty) return null;

    final m = RegExp(r'(\d{2})/(\d{2})/(\d{4})').firstMatch(txt);
    if (m == null) return null;

    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);

    if (d == null || mo == null || y == null) return null;
    return DateTime(y, mo, d);
  }
}
