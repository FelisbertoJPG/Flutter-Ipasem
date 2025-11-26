// lib/api/cards_page_scraper.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;

/// Modelo mínimo para a Home (usa-se ComunicadoResumo depois no repo)
class ScrapedComunicado {
  final String titulo;
  final DateTime? publicadoEm;
  final String? resumo;
  final String? corpoHtml; // opcional, se quiser usar no detalhe

  const ScrapedComunicado({
    required this.titulo,
    required this.publicadoEm,
    required this.resumo,
    required this.corpoHtml,
  });
}

/// Dado o baseApiUrl do gateway (98, assistweb etc),
/// decide qual URL de /comunicacao-app/cards usar.
String buildComunicadosCardsUrlFromBase(String baseApiUrl) {
  final uri = Uri.parse(baseApiUrl);
  final host = uri.host;
  final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme;
  final port = uri.port;

  // Ambiente 98: usa porta 81
  if (host == '192.9.200.98') {
    return 'http://192.9.200.98:81/comunicacao-app/cards';
  }

  // Produção assistweb -> força www.ipasemnh.com.br em https
  if (host.contains('assistweb')) {
    return 'https://www.ipasemnh.com.br/comunicacao-app/cards';
  }

  // Fallback: mesmo host/porta do baseApiUrl
  final effectivePort =
  port == 0 ? (scheme == 'https' ? 443 : 80) : port;

  final bool hidePort =
      (scheme == 'https' && effectivePort == 443) ||
          (scheme == 'http' && effectivePort == 80);

  final portSuffix = hidePort ? '' : ':$effectivePort';

  return '$scheme://$host$portSuffix/comunicacao-app/cards';
}

/// Lê uma página /comunicacao-app/cards e extrai os comunicados exibidos no HTML.
class CardsPageScraper {
  final String pageUrl;

  const CardsPageScraper({required this.pageUrl});

  Future<List<ScrapedComunicado>> fetch({
    int limit = 6,
    String? categoria,
    String? tag,
  }) async {
    final uri = Uri.parse(pageUrl).replace(queryParameters: {
      'limit': '$limit',
      if (categoria != null && categoria.trim().isNotEmpty)
        'categoria': categoria.trim(),
      if (tag != null && tag.trim().isNotEmpty) 'tag': tag.trim(),
    });

    if (kDebugMode) {
      debugPrint('[CardsPageScraper] GET $uri');
    }

    http.Response resp;
    try {
      resp = await http.get(
        uri,
        headers: const {
          // força HTML; não dependemos de JSON
          'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'User-Agent': 'IPASEM-App/1.0',
        },
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CardsPageScraper] http.get error: $e\n$st');
      }
      return const <ScrapedComunicado>[];
    }

    if (kDebugMode) {
      debugPrint(
        '[CardsPageScraper] status=${resp.statusCode} bodyLen=${resp.body.length}',
      );
    }

    if (resp.statusCode != 200) {
      return const <ScrapedComunicado>[];
    }

    final doc = html.parse(resp.body);

    // Layout "cheio" (o primeiro que você colou):
    // <div class="card border-0 shadow-sm"><div class="card-body">...</div></div>
    List<dom.Element> nodes = doc
        .querySelectorAll('div.card.border-0.shadow-sm > div.card-body');

    // Fallback para layout simplificado (segundo snippet):
    // <div class="card mb-3"><div class="card-body"><strong>Título</strong>...</div></div>
    if (nodes.isEmpty) {
      nodes = doc.querySelectorAll('div.card > div.card-body');
    }

    if (kDebugMode) {
      debugPrint('[CardsPageScraper] nós encontrados: ${nodes.length}');
    }

    if (nodes.isEmpty) {
      return const <ScrapedComunicado>[];
    }

    final out = <ScrapedComunicado>[];

    for (final n in nodes) {
      try {
        // Título:
        final titulo = (_txt(n.querySelector('h2.h6')) ??
            _txt(n.querySelector('h2')) ??
            _txt(n.querySelector('strong')) ??
            '')
            .trim();

        if (titulo.isEmpty) {
          continue;
        }

        // Data — linha "Publicado em: dd/mm/yyyy hh:mm" (quando existir)
        final meta = _txt(n.querySelector('.text-muted')) ?? '';
        final publicadoEm = _parseBrDateFromMeta(meta);

        // Resumo (quando existir)
        String? resumo = _txt(n.querySelector('p.mb-2'));
        if (resumo != null &&
            resumo.trim().toLowerCase() == '(sem resumo)') {
          resumo = null;
        }
        resumo = resumo?.trim();
        if (resumo != null && resumo.isEmpty) resumo = null;

        // Corpo opcional dentro de <details><div>...</div></details>
        final corpoHtml =
        n.querySelector('details > div')?.innerHtml?.trim();

        out.add(
          ScrapedComunicado(
            titulo: titulo,
            publicadoEm: publicadoEm,
            resumo: resumo,
            corpoHtml: corpoHtml,
          ),
        );
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[CardsPageScraper] erro ao parsear nó: $e\n$st');
        }
      }
    }

    return out;
  }

  static String? _txt(dom.Element? e) => e?.text;

  static DateTime? _parseBrDateFromMeta(String s) {
    // tenta achar "dd/mm/yyyy hh:mm" ou "dd/mm/yyyy"
    final re =
    RegExp(r'(\d{2})/(\d{2})/(\d{4})(?:\s+(\d{2}):(\d{2}))?');
    final m = re.firstMatch(s);
    if (m == null) return null;
    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    final hh = int.tryParse(m.group(4) ?? '0');
    final mm = int.tryParse(m.group(5) ?? '0');
    if (d == null || mo == null || y == null || hh == null || mm == null) {
      return null;
    }
    // considera America/Sao_Paulo na camada de apresentação; aqui usa local
    return DateTime(y, mo, d, hh, mm);
  }
}
