// lib/screens/historico_autorizacoes_screen.dart
import 'package:flutter/material.dart';

import '../ui/app_shell.dart';
import '../ui/utils/webview_warmup.dart';
import '../ui/utils/service_launcher.dart';
import '../ui/utils/print_helpers.dart';

import '../models/reimpressao.dart';
import '../controllers/home_servicos_controller.dart';
import '../ui/components/reimp_action_sheet.dart';
import '../ui/components/reimp_detalhes_sheet.dart';
import '../state/auth_events.dart';

class HistoricoAutorizacoesScreen extends StatefulWidget {
  const HistoricoAutorizacoesScreen({super.key});

  @override
  State<HistoricoAutorizacoesScreen> createState() =>
      _HistoricoAutorizacoesScreenState();
}

class _HistoricoAutorizacoesScreenState extends State<HistoricoAutorizacoesScreen>
    with WebViewWarmup {
  static const int _pageSize = 10;

  bool _loading = true;
  String? _error;

  HomeServicosController? _controller;
  late final ServiceLauncher _launcher = ServiceLauncher(context, takePrewarmed);

  List<ReimpressaoResumo> _all = const [];
  int _page = 0;

  String? _titularNome;

  VoidCallback? _issuedListener;
  VoidCallback? _printedListener;

  bool _depsReady = false; // garante bootstrap só uma vez

  @override
  void initState() {
    super.initState();

    // Listeners podem ser configurados aqui (não acessam InheritedWidget)
    _issuedListener = () => Future.microtask(_refreshAfterIssue);
    _printedListener = () => Future.microtask(_refreshAfterPrint);
    AuthEvents.instance.lastIssued.addListener(_issuedListener!);
    AuthEvents.instance.lastPrinted.addListener(_printedListener!);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;

    _depsReady = true;

    // Seguro usar context aqui
    warmupInit();
    _bootstrap();
  }

  @override
  void dispose() {
    if (_issuedListener != null) {
      AuthEvents.instance.lastIssued.removeListener(_issuedListener!);
    }
    if (_printedListener != null) {
      AuthEvents.instance.lastPrinted.removeListener(_printedListener!);
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _all = const [];
      _page = 0;
    });

    try {
      _controller ??= await HomeServicosController.init(context);
      _titularNome = await _controller!.profileName();

      final rows = await _controller!.loadHistorico();

      // Ordena mais recentes primeiro
      rows.sort((a, b) {
        final ta = _parseDateTime(a.dataEmissao, a.horaEmissao);
        final tb = _parseDateTime(b.dataEmissao, b.horaEmissao);
        return tb.compareTo(ta);
      });

      if (!mounted) return;
      setState(() {
        _all = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Falha ao carregar histórico: $e';
      });
    }
  }

  Future<void> _refreshAfterIssue() async {
    final numero = AuthEvents.instance.lastIssued.value;
    if (!mounted || numero == null) return;
    if (_controller != null) {
      await _controller!.waitUntilInHistorico(numero);
    }
    if (!mounted) return;
    await _bootstrap();
  }

  Future<void> _refreshAfterPrint() async {
    final numero = AuthEvents.instance.lastPrinted.value;
    if (!mounted || numero == null) return;
    if (_controller != null) {
      await _controller!.waitUntilInHistorico(numero);
    }
    if (!mounted) return;
    await _bootstrap();
  }

  DateTime _parseDateTime(String d, String h) {
    try {
      final ds = d.trim();
      final hs = (h.trim().isEmpty) ? '00:00' : h.trim();
      final parts = ds.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]) ?? 1;
        final mon = int.tryParse(parts[1]) ?? 1;
        final yr = int.tryParse(parts[2]) ?? 1970;
        final tparts = hs.split(':');
        final hh = (tparts.isNotEmpty) ? int.tryParse(tparts[0]) ?? 0 : 0;
        final mm = (tparts.length > 1) ? int.tryParse(tparts[1]) ?? 0 : 0;
        return DateTime(yr, mon, day, hh, mm);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  List<ReimpressaoResumo> get _pageItems {
    final start = _page * _pageSize;
    if (start >= _all.length) return const <ReimpressaoResumo>[];
    final end = (start + _pageSize <= _all.length) ? start + _pageSize : _all.length;
    return _all.sublist(start, end);
  }

  int get _totalPages =>
      _all.isEmpty ? 1 : ((_all.length - 1) ~/ _pageSize) + 1;

  void _prevPage() {
    if (_page == 0) return;
    setState(() => _page -= 1);
  }

  void _nextPage() {
    if (_page >= _totalPages - 1) return;
    setState(() => _page += 1);
  }

  Future<void> _onTapHistorico(ReimpressaoResumo a) async {
    if (!mounted) return;
    final action = await showReimpActionSheet(context, a);
    if (action == null) return;
    switch (action) {
      case ReimpAction.detalhes:
        await _showDetalhes(
          a.numero,
          pacienteFallback: (a.paciente.trim().isNotEmpty)
              ? a.paciente
              : (_titularNome ?? ''),
        );
        break;
      case ReimpAction.pdfLocal:
        await openPreviewFromNumero(context, a.numero);
        break;
    }
  }

  Future<void> _showDetalhes(int numero, {String? pacienteFallback}) async {
    if (_controller == null) return;
    ReimpressaoDetalhe? det;
    try {
      det = await _controller!.loadDetalhe(numero);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar detalhes: $e')),
        );
      }
    }
    if (!mounted || det == null) return;

    await showReimpDetalhesSheet(
      context: context,
      det: det,
      pacienteFallback: pacienteFallback,
      onPrintViaSite: () {
        _launcher.openUrl(
          'https://assistweb.ipasemnh.com.br/site/login',
          'Reimpressão de Autorizações',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Histórico de Autorizações',
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
            : (_all.isEmpty)
            ? const Center(child: Text('Nenhuma autorização encontrada.'))
            : Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _pageItems.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final h = _pageItems[i];

                  final paciente = (h.paciente.trim().isNotEmpty)
                      ? h.paciente.trim()
                      : (_titularNome?.trim() ?? '');

                  final hasData = h.dataEmissao.isNotEmpty;
                  final hasHora = h.horaEmissao.isNotEmpty;

                  final titulo = h.prestadorExec.isNotEmpty
                      ? h.prestadorExec
                      : (paciente.isNotEmpty
                      ? paciente
                      : 'Autorização ${h.numero}');

                  final subParts = <String>[];
                  if (hasData && hasHora) {
                    subParts.add('${h.dataEmissao} • ${h.horaEmissao}');
                  } else if (hasData) {
                    subParts.add(h.dataEmissao);
                  }
                  if (paciente.isNotEmpty) subParts.add('• $paciente');
                  final subtitulo = subParts.join(' ');

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      subtitulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _onTapHistorico(h),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _page == 0 ? null : _prevPage,
                    child: const Text('Anterior'),
                  ),
                  const Spacer(),
                  Text('Página ${_page + 1} de $_totalPages'),
                  const Spacer(),
                  TextButton(
                    onPressed: (_page >= _totalPages - 1) ? null : _nextPage,
                    child: const Text('Próxima'),
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
