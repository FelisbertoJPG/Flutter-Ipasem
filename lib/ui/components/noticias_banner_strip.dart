// lib/ui/components/noticias_banner_strip.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/banner_app_scraper.dart';

class NoticiasBannerStrip extends StatefulWidget {
  final String feedUrl;
  final double height;
  final EdgeInsetsGeometry? margin;

  const NoticiasBannerStrip({
    super.key,
    required this.feedUrl,
    this.height = 160,
    this.margin,
  });

  @override
  State<NoticiasBannerStrip> createState() => _NoticiasBannerStripState();
}

class _NoticiasBannerStripState extends State<NoticiasBannerStrip> {
  late Future<List<ScrapedBannerImage>> _future;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('[NoticiasBannerStrip] initState feedUrl=${widget.feedUrl}');
    }
    _future = BannerAppScraper(pageUrl: widget.feedUrl).fetchBanners();
  }

  @override
  void didUpdateWidget(covariant NoticiasBannerStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedUrl != widget.feedUrl) {
      if (kDebugMode) {
        debugPrint(
          '[NoticiasBannerStrip] feedUrl alterado: '
              '"${oldWidget.feedUrl}" -> "${widget.feedUrl}"',
        );
      }
      _future = BannerAppScraper(pageUrl: widget.feedUrl).fetchBanners();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = SizedBox(
      height: widget.height,
      child: FutureBuilder<List<ScrapedBannerImage>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          if (snapshot.hasError) {
            if (kDebugMode) {
              debugPrint(
                  '[NoticiasBannerStrip] erro ao carregar: ${snapshot.error}');
            }
            return _NoticiasErrorCard(
              message: 'Não foi possível carregar as notícias.',
              detail: kDebugMode ? snapshot.error.toString() : null,
            );
          }

          final banners = snapshot.data ?? const <ScrapedBannerImage>[];
          if (banners.isEmpty) {
            if (kDebugMode) {
              debugPrint(
                  '[NoticiasBannerStrip] nenhum banner retornado da página.');
            }
            return const _NoticiasErrorCard(
              message: 'Sem banners para o período atual.',
            );
          }

          // Por enquanto: usa só o primeiro banner.
          final banner = banners.first;

          return _BannerCard(banner: banner);
        },
      ),
    );

    if (widget.margin != null) {
      return Padding(
        padding: widget.margin!,
        child: body,
      );
    }
    return body;
  }
}

class _BannerCard extends StatelessWidget {
  final ScrapedBannerImage banner;

  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagem de fundo
          Image.network(
            banner.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                debugPrint(
                    '[NoticiasBannerStrip] erro ao desenhar imagem: $error');
              }
              return Container(
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image,
                  size: 48,
                ),
              );
            },
          ),
          // Fade no rodapé com o título
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    Colors.black87,
                    Colors.black54,
                    Colors.transparent,
                  ],
                ),
              ),
              child: Text(
                banner.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticiasErrorCard extends StatelessWidget {
  final String message;
  final String? detail;

  const _NoticiasErrorCard({
    required this.message,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Junta mensagem + detalhe (apenas em debug) em um único Text,
    // sem Column vertical, pra não dar overflow.
    String fullText = message;
    if (detail != null &&
        detail!.isNotEmpty &&
        kDebugMode) {
      fullText = '$message\n$detail';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          color: Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fullText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
