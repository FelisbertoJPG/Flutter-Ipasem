// lib/ui/components/noticias_banner_strip.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/banner_app_scraper.dart';

class NoticiasBannerStrip extends StatefulWidget {
  /// URL completa da página HTML que contém os banners
  /// (ex.: https://www.ipasemnh.com.br/app-banner/banner-app).
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
          '[NoticiasBannerStrip] feedUrl alterado '
              'de=${oldWidget.feedUrl} para=${widget.feedUrl}',
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
                '[NoticiasBannerStrip] erro ao carregar: ${snapshot.error}',
              );
            }
            return _NoticiasErrorCard(
              message: 'Não foi possível carregar os banners.',
              detail: kDebugMode ? snapshot.error.toString() : null,
            );
          }

          final rawBanners = snapshot.data ?? const <ScrapedBannerImage>[];
          // Limita a, no máximo, 3 banners no carrossel.
          final banners = rawBanners.take(3).toList();

          if (banners.isEmpty) {
            return const _NoticiasErrorCard(
              message: 'Nenhum banner disponível para o período atual.',
            );
          }

          // Se só existir 1 banner, mantém o comportamento anterior:
          if (banners.length == 1) {
            return _BannerCard(banner: banners.first);
          }

          // Com 2 ou 3 banners, exibe carrossel automático.
          return _BannerCarousel(
            banners: banners,
            interval: const Duration(seconds: 2),
          );
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

class _BannerCarousel extends StatefulWidget {
  final List<ScrapedBannerImage> banners;
  final Duration interval;

  const _BannerCarousel({
    required this.banners,
    this.interval = const Duration(seconds: 2),
  });

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant _BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.banners.length != widget.banners.length) {
      // Reinicia o carrossel se a quantidade de banners mudar.
      _currentPage = 0;
      _pageController.jumpToPage(0);
      _restartAutoSlide();
    }
  }

  void _startAutoSlide() {
    if (widget.banners.length <= 1) return;

    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (timer) {
      if (!mounted) return;
      if (widget.banners.isEmpty) return;

      final nextPage = (_currentPage + 1) % widget.banners.length;

      if (kDebugMode) {
        debugPrint(
          '[NoticiasBannerStrip] auto-slide: $_currentPage -> $nextPage',
        );
      }

      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _currentPage = nextPage;
    });
  }

  void _restartAutoSlide() {
    _timer?.cancel();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.banners.length,
      onPageChanged: (index) {
        _currentPage = index;
      },
      itemBuilder: (context, index) {
        final banner = widget.banners[index];
        return _BannerCard(banner: banner);
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  final ScrapedBannerImage banner;

  const _BannerCard({required this.banner});

  ImageProvider<Object>? _buildImageProvider(String raw) {
    final src = raw.trim();
    if (src.isEmpty) return null;

    // Caso 1: data:image/...;base64,...
    if (src.startsWith('data:image')) {
      if (kDebugMode) {
        debugPrint(
          '[NoticiasBannerStrip] _buildImageProvider: data URI '
              'prefix=${src.substring(0, src.length > 40 ? 40 : src.length)}...',
        );
      }
      try {
        final commaIndex = src.indexOf(',');
        if (commaIndex <= 0 || commaIndex >= src.length - 1) {
          return null;
        }
        final base64Part = src.substring(commaIndex + 1);
        final Uint8List bytes = base64Decode(base64Part);
        return MemoryImage(bytes);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[NoticiasBannerStrip] erro ao decodificar data URI: $e',
          );
        }
        return null;
      }
    }

    // Caso 2: URL http/https normal.
    if (kDebugMode) {
      debugPrint('[NoticiasBannerStrip] _buildImageProvider: NetworkImage=$src');
    }
    return NetworkImage(src);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = _buildImageProvider(banner.imageUrl);

    if (provider == null) {
      if (kDebugMode) {
        debugPrint(
          '[NoticiasBannerStrip] provider nulo, exibindo placeholder de imagem.',
        );
      }
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagem de fundo (aceita tanto MemoryImage quanto NetworkImage).
          Image(
            image: provider,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                debugPrint(
                  '[NoticiasBannerStrip] erro ao desenhar imagem: $error',
                );
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        color: Colors.red.shade50,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail != null && detail!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade800.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


