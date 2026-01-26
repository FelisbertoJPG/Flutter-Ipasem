import 'dart:convert';

/// Modelo tolerante a variações do payload (mapRowToApi) vindas do backend.
/// Campos opcionais são preenchidos por fallback de chaves: ex. 'titulo' | 'title'.
class Comunicado {
  final int id;
  final String? categoria;
  final List<String> tags;
  final int? ordem;

  final String? titulo;
  final String? subtitulo;
  final String? resumo;
  final String? corpoHtml;   // caso backend envie HTML
  final String? corpoTexto;  // texto puro (quando disponível)

  final DateTime? publicadoEm;
  final DateTime? expiraEm;

  final String? imagemUrl;
  final String? linkUrl;

  /// Guarda o mapa original para auditoria/diagnóstico.
  final Map<String, dynamic> raw;

  Comunicado({
    required this.id,
    required this.raw,
    this.categoria,
    this.tags = const [],
    this.ordem,
    this.titulo,
    this.subtitulo,
    this.resumo,
    this.corpoHtml,
    this.corpoTexto,
    this.publicadoEm,
    this.expiraEm,
    this.imagemUrl,
    this.linkUrl,
  });

  static String? _pickString(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static int? _pickInt(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is int) return v;
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return p;
      }
    }
    return null;
  }

  static DateTime? _pickDate(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is int) {
        // epoch seconds or millis
        if (v > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v, isUtc: false);
        }
        if (v > 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: false);
        }
      }
      if (v is String) {
        // tenta ISO-8601 ou "YYYY-MM-DD HH:mm:ss"
        try {
          return DateTime.parse(v);
        } catch (_) {
          // tenta normalizar "YYYY-MM-DD HH:mm:ss"
          final s = v.replaceFirst(' ', 'T');
          try {
            return DateTime.parse(s);
          } catch (_) {}
        }
      }
    }
    return null;
  }

  static List<String> _parseTags(dynamic v) {
    if (v == null) return const [];
    if (v is List) {
      return v.map((e) => '$e').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    if (v is String) {
      // CSV simples: "saúde, alerta"
      return v
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static Comunicado fromApi(Map<String, dynamic> row) {
    final id =
        _pickInt(row, const ['id', 'codigo', 'comunicado_id']) ?? 0;

    final categoria = _pickString(row, const ['categoria', 'category']);

    final ordem = _pickInt(row, const ['ordem', 'order', 'position']);

    final titulo = _pickString(row, const ['titulo', 'title', 'nome']);
    final subtitulo = _pickString(row, const ['subtitulo', 'subtitle', 'chamada']);
    final resumo = _pickString(row, const ['resumo', 'summary', 'descricao_curta']);

    final corpoHtml = _pickString(row, const ['corpo_html', 'html', 'conteudo', 'content_html']);
    final corpoTexto = _pickString(row, const ['corpo_texto', 'text', 'content_text']);

    final publicadoEm = _pickDate(row, const ['data_publicacao', 'published_at', 'inicio_publicacao']);
    final expiraEm    = _pickDate(row, const ['data_expiracao', 'expires_at', 'fim_publicacao']);

    final imagemUrl = _pickString(row, const ['imagem', 'image', 'imagem_url', 'image_url']);
    final linkUrl   = _pickString(row, const ['link', 'url', 'permalink']);

    final tags = _parseTags(row['tags']);

    return Comunicado(
      id: id,
      raw: row,
      categoria: categoria,
      ordem: ordem,
      titulo: titulo,
      subtitulo: subtitulo,
      resumo: resumo,
      corpoHtml: corpoHtml,
      corpoTexto: corpoTexto,
      publicadoEm: publicadoEm,
      expiraEm: expiraEm,
      imagemUrl: imagemUrl,
      linkUrl: linkUrl,
      tags: tags,
    );
  }

  /// Utilidade para diagnóstico rápido.
  String debugJson() => const JsonEncoder.withIndent('  ').convert(raw);
}

class PaginatedComunicados {
  final List<Comunicado> rows;
  final int limit;
  final int offset;

  PaginatedComunicados({
    required this.rows,
    required this.limit,
    required this.offset,
  });
}
