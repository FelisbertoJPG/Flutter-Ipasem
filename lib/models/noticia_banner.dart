// lib/models/noticia_banner.dart
import 'dart:convert';

/// Modelo de notícia para o banner/strip.
/// Funciona tanto com payload JSON (API) quanto com scraping de HTML,
/// desde que os campos sejam mapeados via `fromApi`.
class NoticiaBanner {
  final int id;
  final String? titulo;
  final String? resumo;
  final String? imagemUrl;
  final String? linkUrl;
  final DateTime? data;

  /// Mapa original (quando vier de JSON), útil para debug/log.
  final Map<String, dynamic>? raw;

  const NoticiaBanner({
    required this.id,
    this.titulo,
    this.resumo,
    this.imagemUrl,
    this.linkUrl,
    this.data,
    this.raw,
  });

  // ===== Helpers internos de parsing genérico =====

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
        final n = int.tryParse(v);
        if (n != null) return n;
      }
    }
    return null;
  }

  static DateTime? _pickDate(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;

      // Epoch em segundos/millis
      if (v is int) {
        if (v > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v, isUtc: false);
        }
        if (v > 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: false);
        }
      }

      if (v is String) {
        final s = v.trim();
        if (s.isEmpty) continue;

        // Tenta ISO direto
        try {
          return DateTime.parse(s);
        } catch (_) {
          // Tenta normalizar "YYYY-MM-DD HH:mm:ss"
          final norm = s.replaceFirst(' ', 'T');
          try {
            return DateTime.parse(norm);
          } catch (_) {}

          // Tenta dd/MM/yyyy bem simples
          final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(s);
          if (br != null) {
            final d = int.parse(br.group(1)!);
            final mo = int.parse(br.group(2)!);
            final y = int.parse(br.group(3)!);
            return DateTime(y, mo, d);
          }
        }
      }
    }
    return null;
  }

  /// Criação a partir de um row genérico (API JSON).
  ///
  /// Campos tolerados:
  /// - id:            `id` | `noticia_id`
  /// - titulo:        `titulo` | `title`
  /// - resumo:        `subtitulo` | `resumo` | `summary`
  /// - imagemUrl:     `imagem_url` | `image_url` | `imagem` | `image`
  /// - linkUrl:       `link_url` | `url` | `permalink`
  /// - data:          `data_postagem` | `data_post` | `published_at`
  static NoticiaBanner fromApi(Map<String, dynamic> row) {
    final id = _pickInt(row, const ['id', 'noticia_id']) ?? 0;
    final titulo = _pickString(row, const ['titulo', 'title']);
    final resumo =
    _pickString(row, const ['subtitulo', 'resumo', 'summary', 'chamada']);
    final imagemUrl =
    _pickString(row, const ['imagem_url', 'image_url', 'imagem', 'image']);
    final linkUrl =
    _pickString(row, const ['link_url', 'url', 'permalink', 'href']);
    final data = _pickDate(
      row,
      const ['data_postagem', 'data_post', 'published_at'],
    );

    return NoticiaBanner(
      id: id,
      titulo: titulo,
      resumo: resumo,
      imagemUrl: imagemUrl,
      linkUrl: linkUrl,
      data: data,
      raw: row,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'resumo': resumo,
    'imagem_url': imagemUrl,
    'link_url': linkUrl,
    'data_iso': data?.toIso8601String(),
  };

  String debugJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
