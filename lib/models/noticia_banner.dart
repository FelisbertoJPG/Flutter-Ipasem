// lib/models/noticia_banner.dart

class NoticiaBanner {
  final int id;
  final String? titulo;
  final String? resumo;
  final String? imagemUrl;
  final String? linkUrl;
  final int? posicao;
  final bool ativo;

  const NoticiaBanner({
    required this.id,
    this.titulo,
    this.resumo,
    this.imagemUrl,
    this.linkUrl,
    this.posicao,
    required this.ativo,
  });

  /// Constrói a partir de 1 linha do JSON do endpoint PHP
  /// (AppBannerService::toApi):
  ///
  /// {
  ///   "id": 1,
  ///   "titulo": "teste banner",
  ///   "resumo": null,
  ///   "imagem": "/file/...." ou "https://...",
  ///   "imagem_url": "...",
  ///   "link": null,
  ///   "link_url": null,
  ///   "posicao": 1,
  ///   "ativo": true
  /// }
  factory NoticiaBanner.fromJson(Map<String, dynamic> json) {
    return NoticiaBanner(
      id: (json['id'] as num?)?.toInt() ?? 0,
      titulo: json['titulo'] as String?,
      resumo: json['resumo'] as String?,
      imagemUrl: (json['imagem_url'] ?? json['imagem']) as String?,
      linkUrl: (json['link_url'] ?? json['link']) as String?,
      posicao: (json['posicao'] as num?)?.toInt(),
      ativo: (() {
        final v = json['ativo'];
        if (v is bool) return v;
        if (v is num) return v != 0;
        return true;
      })(),
    );
  }

  NoticiaBanner copyWith({
    String? titulo,
    String? resumo,
    String? imagemUrl,
    String? linkUrl,
    int? posicao,
    bool? ativo,
  }) {
    return NoticiaBanner(
      id: id,
      titulo: titulo ?? this.titulo,
      resumo: resumo ?? this.resumo,
      imagemUrl: imagemUrl ?? this.imagemUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      posicao: posicao ?? this.posicao,
      ativo: ativo ?? this.ativo,
    );
  }
}
