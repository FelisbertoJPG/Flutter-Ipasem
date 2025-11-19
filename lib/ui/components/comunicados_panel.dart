import 'package:flutter/material.dart';
import '../../models/comunicado.dart';
import '../../services/comunicados_app_service.dart';

/// Painel simples para listar comunicados ativos a partir das views JSON do Yii.
/// Uso típico:
///   const ComunicadosPanel(limit: 5, categoria: 'home');
class ComunicadosPanel extends StatefulWidget {
  final int limit;
  final String? categoria;
  final String? tag;
  final EdgeInsetsGeometry padding;

  const ComunicadosPanel({
    super.key,
    this.limit = 10 ,//limite de publicações
    this.categoria,
    this.tag,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  State<ComunicadosPanel> createState() => _ComunicadosPanelState();
}

class _ComunicadosPanelState extends State<ComunicadosPanel> {
  final _svc = ComunicacaoAppService();
  Future<PaginatedComunicados>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ComunicadosPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.limit != widget.limit ||
        oldWidget.categoria != widget.categoria ||
        oldWidget.tag != widget.tag) {
      _load();
    }
  }

  void _load() {
    _future = _svc.list(
      limit: widget.limit,
      categoria: widget.categoria,
      tag: widget.tag,
    );
    setState(() {}); // dispara rebuild para o FutureBuilder
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: FutureBuilder<PaginatedComunicados>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _Skeleton();
          }
          if (snap.hasError) {
            return const _ErrorBox(message: 'Comunicados indisponíveis no momento.');
          }
          final data = snap.data;
          final rows = data?.rows ?? const <Comunicado>[];
          if (rows.isEmpty) {
            return const _EmptyBox(message: 'Nenhum comunicado no momento.');
          }
          return _ListBox(rows: rows, service: _svc);
        },
      ),
    );
  }
}

class _ListBox extends StatelessWidget {
  final List<Comunicado> rows;
  final ComunicacaoAppService service;

  const _ListBox({required this.rows, required this.service});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in rows) _ComunicadoTile(comunicado: c, service: service),
      ],
    );
  }
}

class _ComunicadoTile extends StatelessWidget {
  final Comunicado comunicado;
  final ComunicacaoAppService service;

  const _ComunicadoTile({required this.comunicado, required this.service});

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  String _firstNonEmpty(List<String?> xs) {
    for (final x in xs) {
      if (x != null && x.trim().isNotEmpty) return x.trim();
    }
    return '';
  }

  String _plainPreview(Comunicado c) {
    // prioridade: resumo > corpoTexto > corpoHtml (strippado) > subtitulo
    final r = _firstNonEmpty([c.resumo, c.corpoTexto, c.subtitulo]);
    if (r.isNotEmpty) return r;
    final html = c.corpoHtml ?? '';
    return _stripHtml(html).take(220);
  }

  String _stripHtml(String html) {
    // remoção simples de tags; suficiente para preview
    return html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final title = _firstNonEmpty([comunicado.titulo, comunicado.resumo, 'Comunicado']);
    final subtitle = _plainPreview(comunicado);
    final date = _fmtDate(comunicado.publicadoEm);

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: comunicado.imagemUrl != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            comunicado.imagemUrl!,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => const Icon(Icons.campaign_outlined, size: 36),
          ),
        )
            : const Icon(Icons.campaign_outlined, size: 36),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle.isEmpty
            ? null
            : Text(
          subtitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: date.isEmpty ? null : Text(date, style: const TextStyle(fontSize: 12)),
        onTap: () async {
          // Busca o detalhe via /api-view, se necessário (exibe diálogo simples).
          final full = await service.view(comunicado.id);
          if (full == null) return;
          // Mostra detalhes em um diálogo mínimo; substitua por uma página se preferir.
          // Se existir corpoHtml, mostramos strippado; para HTML rico, usar flutter_html (opcional).
          final text = full.corpoTexto ??
              full.resumo ??
              _stripHtml(full.corpoHtml ?? full.raw.toString());
          // ignore: use_build_context_synchronously
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(full.titulo ?? 'Comunicado'),
              content: SingleChildScrollView(child: Text(text)),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
            (_) => Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: 72,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String message;
  const _EmptyBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }
}

extension _TakeExt on String {
  String take(int max) => length <= max ? this : substring(0, max);
}
