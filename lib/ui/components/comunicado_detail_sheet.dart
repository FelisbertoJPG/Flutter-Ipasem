// lib/ui/components/comunicado_detail_sheet.dart
import 'package:flutter/material.dart';

import '../../core/models.dart' show ComunicadoResumo;
import '../../config/app_config.dart';
import '../../api/cards_page_scraper.dart';

/// Bottom-sheet de detalhe do Comunicado.
/// Não depende de endpoint JSON: re-scrapeia /comunicacao-app/cards
/// e acha o corpo pelo título.
class ComunicadoDetailSheet extends StatefulWidget {
  final ComunicadoResumo resumo;

  const ComunicadoDetailSheet.fromResumo({
    super.key,
    required this.resumo,
  });

  @override
  State<ComunicadoDetailSheet> createState() =>
      _ComunicadoDetailSheetState();
}

class _ComunicadoDetailSheetState extends State<ComunicadoDetailSheet> {
  bool _loading = true;
  String? _error;
  String? _title;
  DateTime? _date;
  String? _bodyPlain; // corpo strippado

  // URL final de /comunicacao-app/cards (já resolvida com base no ambiente)
  String? _cardsUrl;
  bool _startedLoad = false;

  @override
  void initState() {
    super.initState();
    // Não chama _load aqui; precisamos do AppConfig (context).
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_startedLoad) return;
    _startedLoad = true;

    final cfg = AppConfig.of(context);
    final baseApiUrl = cfg.params.baseApiUrl;

    _cardsUrl = buildComunicadosCardsUrlFromBase(baseApiUrl);

    _load();
  }

  Future<void> _load() async {
    try {
      final resumo = widget.resumo;
      _title = resumo.titulo;
      _date = resumo.data;

      if (_cardsUrl == null) {
        setState(() {
          _error = 'URL de comunicados indisponível.';
          _loading = false;
        });
        return;
      }

      // Busca novamente a página de cards no HOST correto
      final scraper = CardsPageScraper(pageUrl: _cardsUrl!);
      final rows = await scraper.fetch(limit: 20); // margem de segurança

      String? html;
      DateTime? foundDate;

      final needle = resumo.titulo.trim().toLowerCase();
      for (final r in rows) {
        final rt = r.titulo.trim().toLowerCase();
        if (rt == needle) {
          html = r.corpoHtml;
          foundDate = r.publicadoEm ?? foundDate;
          break;
        }
      }

      // Fallback: usa descrição do resumo caso não ache HTML
      String plain;
      if (html != null && html.trim().isNotEmpty) {
        plain = _stripHtml(html);
      } else {
        final desc = (resumo.descricao ?? '').trim();
        plain = desc.isNotEmpty
            ? desc
            : '(sem conteúdo disponível)';
      }

      if (!mounted) return;
      setState(() {
        _date = _date ?? foundDate;
        _bodyPlain = plain;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString().padLeft(4, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$mi';
  }

  String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  @override
  Widget build(BuildContext context) {
    final title = _title ?? 'Comunicado';
    final date = _fmtDate(_date);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _loading
                    ? const Center(
                  child: CircularProgressIndicator(),
                )
                    : _error != null
                    ? const _ErrorBox(
                  message:
                  'Falha ao abrir comunicado.',
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (date.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 2, bottom: 12),
                        child: Text(
                          'Publicado em: $date',
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: controller,
                        padding: const EdgeInsets.only(
                            bottom: 12),
                        child: SelectableText(
                          _bodyPlain ?? '',
                          style: const TextStyle(
                            height: 1.25,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.red),
        textAlign: TextAlign.center,
      ),
    );
  }
}
