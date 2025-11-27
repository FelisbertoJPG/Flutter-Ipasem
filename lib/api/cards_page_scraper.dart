import 'dart:async';
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

/// Lê https://www.ipasemnh.com.br/comunicacao-app/cards?limit=6
/// e extrai os comunicados exibidos no HTML.
class CardsPageScraper {
  final String baseUrl;
  final String path;

  const CardsPageScraper({
    this.baseUrl = 'https://www.ipasemnh.com.br',
    this.path = '/comunicacao-app/cards',
  });

  Future<List<ScrapedComunicado>> fetch({
    int limit = 6,
    String? categoria,
    String? tag,
  }) async {
    final uri = Uri.parse(baseUrl + path).replace(queryParameters: {
      'limit': '$limit',
      if (categoria != null && categoria.trim().isNotEmpty) 'categoria': categoria.trim(),
      if (tag != null && tag.trim().isNotEmpty) 'tag': tag.trim(),
    });

    final resp = await http.get(uri, headers: {
      // força HTML mesmo; não dependemos de JSON
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'User-Agent': 'IPASEM-App/1.0',
    });

    if (resp.statusCode != 200) {
      throw StateError('HTTP ${resp.statusCode} ao carregar $uri');
    }

    final doc = html.parse(resp.body);

    // Cada comunicado está como um "card border-0 shadow-sm" com "card-body"
    final nodes = doc.querySelectorAll('div.card.border-0.shadow-sm > div.card-body');
    if (nodes.isEmpty) {
      // página retornou “Nenhum comunicado...”
      return const <ScrapedComunicado>[];
    }

    final out = <ScrapedComunicado>[];
    for (final n in nodes) {
      // Título
      final titulo = _txt(n.querySelector('h2.h6')) ?? _txt(n.querySelector('h2')) ?? '';

      // Data — linha "Publicado em: dd/mm/yyyy hh:mm"
      final meta = _txt(n.querySelector('.text-muted')) ?? '';
      final publicadoEm = _parseBrDateFromMeta(meta);

      // Resumo (p.mb-2; quando não existe, pode vir "(sem resumo)")
      String? resumo = _txt(n.querySelector('p.mb-2'));
      if (resumo != null && resumo.trim().toLowerCase() == '(sem resumo)') {
        resumo = null;
      }
      if (resumo != null) resumo = resumo.trim();

      // Corpo opcional dentro de <details> <div>...</div>
      final corpoHtml = n.querySelector('details > div')?.innerHtml?.trim();

      out.add(ScrapedComunicado(
        titulo: titulo.trim(),
        publicadoEm: publicadoEm,
        resumo: resumo,
        corpoHtml: corpoHtml,
      ));
    }

    return out;
  }

  static String? _txt(dom.Element? e) => e?.text;

  static DateTime? _parseBrDateFromMeta(String s) {
    // tenta achar "dd/mm/yyyy hh:mm" ou "dd/mm/yyyy"
    final re = RegExp(r'(\d{2})/(\d{2})/(\d{4})(?:\s+(\d{2}):(\d{2}))?');
    final m = re.firstMatch(s);
    if (m == null) return null;
    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    final hh = int.tryParse(m.group(4) ?? '0');
    final mm = int.tryParse(m.group(5) ?? '0');
    if (d == null || mo == null || y == null || hh == null || mm == null) return null;
    // considera America/Sao_Paulo na camada de apresentação; aqui usa-se local
    return DateTime(y, mo, d, hh, mm);
  }
}
