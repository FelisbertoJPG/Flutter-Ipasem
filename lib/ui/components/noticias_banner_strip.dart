// lib/ui/components/noticias_banner_strip.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/noticia_banner.dart';
import '../../services/noticias_banner_service.dart';

/// Faixa de notícias em destaque para a parte superior do app,
/// ou dentro do Drawer abaixo de "Menu".
///
/// Uso típico:
///   const NoticiasBannerStrip(
///     feedUrl: 'https://www.ipasemnh.com.br/materias?ordenacao=1',
///     limit: 3,
///   );
class NoticiasBannerStrip extends StatefulWidget {
  final String feedUrl;
  final int limit;
  final double height;
  final EdgeInsetsGeometry margin;

  const NoticiasBannerStrip({
    super.key,
    required this.feedUrl,
    this.limit = 3,
    this.height = 150,
    this.margin = const EdgeInsets.fromLTRB(12, 4, 12, 8),
  });

  @override
  State<NoticiasBannerStrip> createState() => _NoticiasBannerStripState();
}

class _NoticiasBannerStripState extends State<NoticiasBannerStrip> {
  late NoticiasBannerService _svc;
  Future<List<NoticiaBanner>>? _future;

  final PageController _pageController =
  PageController(viewportFraction: 0.94);

  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _svc = NoticiasBannerService(feedUrl: widget.feedUrl);
    _load();
  }

  @override
  void didUpdateWidget(covariant NoticiasBannerStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedUrl != widget.feedUrl ||
        oldWidget.limit != widget.limit) {
      _svc = NoticiasBannerService(feedUrl: widget.feedUrl);
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _load() {
    _timer?.cancel();
    if (widget.feedUrl.isEmpty) {
      _future = Future.value(const <NoticiaBanner>[]);
    } else {
      _future = _svc.listarUltimas(limit: widget.limit);
    }
    setState(() {});
  }

  void _setupAutoPlay(int itemCount) {
    _timer?.cancel();
    if (itemCount <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 6), (t) {
      if (!_pageController.hasClients || !mounted) return;
      _current = (_current + 1) % itemCount;
      _pageController.animateToPage(
        _current,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Se não houver URL configurada, não renderiza nada.
    if (widget.feedUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<NoticiaBanner>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          // Enquanto carrega, mostra o esqueleto com altura definida.
          return _SkeletonStrip(
            height: widget.height,
            margin: widget.margin,
          );
        }

        if (snap.hasError) {
          // Em caso de erro, mostra um card com mensagem e erro real.
          return _ErrorStrip(
            height: widget.height,
            margin: widget.margin,
            error: snap.error!,
          );
        }

        final rows = snap.data ?? const <NoticiaBanner>[];
        if (rows.isEmpty) {
          // Sem notícias → mostra um estado vazio discreto.
          return _EmptyStrip(
            height: widget.height,
            margin: widget.margin,
          );
        }

        // Autoplay configurado somente depois de ter dados.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _setupAutoPlay(rows.length);
          }
        });

        return SizedBox(
          height: widget.height,
          child: _BannerPager(
            items: rows,
            pageController: _pageController,
            currentIndex: _current,
            onPageChanged: (idx) {
              setState(() {
                _current = idx;
              });
            },
            height: widget.height,
            margin: widget.margin,
          ),
        );
      },
    );
  }
}

class _BannerPager extends StatelessWidget {
  final List<NoticiaBanner> items;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final double height;
  final EdgeInsetsGeometry margin;

  const _BannerPager({
    required this.items,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.height,
    required this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: pageController,
              onPageChanged: onPageChanged,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final n = items[index];
                return _NoticiaSlide(item: n);
              },
            ),
            // Indicadores (bolinhas) no rodapé direito
            Positioned(
              right: 12,
              bottom: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(items.length, (i) {
                  final active = i == currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: active ? 10 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: active
                          ? Colors.white.withOpacity(0.95)
                          : Colors.white.withOpacity(0.45),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticiaSlide extends StatelessWidget {
  final NoticiaBanner item;

  const _NoticiaSlide({required this.item});

  String _buildTitle() {
    final t = (item.titulo ?? '').trim();
    return t.isEmpty ? 'Notícia' : t;
  }

  String _buildResumo() {
    final r = (item.resumo ?? '').trim();
    if (r.isEmpty) return '';
    return r.length <= 120 ? r : '${r.substring(0, 117)}...';
  }

  @override
  Widget build(BuildContext context) {
    final title = _buildTitle();
    final resumo = _buildResumo();

    Widget content = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE5ECF5),
        image: item.imagemUrl != null
            ? DecorationImage(
          image: NetworkImage(item.imagemUrl!),
          fit: BoxFit.cover,
          onError: (_, __) {},
        )
            : null,
      ),
      child: Container(
        // Overlay em gradiente escuro para texto legível sobre a foto
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.05),
              Colors.black.withOpacity(0.55),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chip "Notícias"
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Notícias',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.25,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
            if (resumo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                resumo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.25,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Ponto para futura navegação:
          // - abrir item.linkUrl com url_launcher
          // - ou navegar para uma tela interna de notícia
        },
        child: content,
      ),
    );
  }
}

class _SkeletonStrip extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry margin;

  const _SkeletonStrip({
    required this.height,
    required this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class _EmptyStrip extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry margin;

  const _EmptyStrip({
    required this.height,
    required this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Text(
          'Nenhuma notícia publicada no momento.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF667085),
          ),
        ),
      ),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry margin;
  final Object error;

  const _ErrorStrip({
    required this.height,
    required this.margin,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final errText = error.toString();

    return Padding(
      padding: margin,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2F2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Falha ao carregar notícias.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    errText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
