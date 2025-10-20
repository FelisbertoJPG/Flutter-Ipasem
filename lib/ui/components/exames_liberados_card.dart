import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/exame.dart';
import '../../repositories/exames_repository.dart';
import '../../services/dev_api.dart';
import '../../services/session.dart';

import '../components/section_card.dart';
import '../components/loading_placeholder.dart';
import '../sheets/exame_detalhe_sheet.dart';

// abre o preview/print do PDF no app
import '../utils/print_helpers.dart';

class ExamesLiberadosCard extends StatefulWidget {
  const ExamesLiberadosCard({super.key});

  @override
  State<ExamesLiberadosCard> createState() => _ExamesLiberadosCardState();
}

class _ExamesLiberadosCardState extends State<ExamesLiberadosCard> {
  late DevApi _api;
  late ExamesRepository _repo;
  bool _ready = false;

  bool _loading = true;
  String? _error;
  List<ExameResumo> _itens = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;

    final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
        ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');
    _api = DevApi(baseUrl);
    _repo = ExamesRepository(_api);

    _ready = true;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _itens = const []; });
    try {
      final profile = await Session.getProfile();
      if (profile == null) {
        setState(() {
          _error = 'Faça login para ver suas autorizações.';
          _loading = false;
        });
        return;
      }
      final rows = await _repo.listarLiberadas(idMatricula: profile.id, limit: 0);
      rows.sort((a, b) => b.dataHora.compareTo(a.dataHora)); // mais recentes primeiro
      setState(() { _itens = rows; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Erro ao carregar autorizações.'; _loading = false; });
    }
  }

  /// Abre o PDF no app, aguarda o retorno, marca A->R no servidor,
  /// remove da lista local e recarrega da API.
  Future<void> _openPdfNoApp(int numero) async {
    if (!mounted) return;

    // 1) Abre o PDF e aguarda fechar
    await openPreviewFromNumeroExame(context, numero, useRootNavigator: true);

    // 2) Marca como reimpressão no servidor (A -> R)
    try {
      final profile = await Session.getProfile();
      if (profile != null) {
        await _repo.registrarPrimeiraImpressao(
          numero: numero,
          idMatricula: profile.id,
        );
      }
    } catch (_) {
      // silencioso para não travar UX; o fallback do repo já tentou `exame_concluir`
    }

    // 3) Remoção otimista local
    if (!mounted) return;
    setState(() {
      _itens = _itens.where((x) => x.numero != numero).toList();
    });

    // 4) Recarrega para consolidar estado vindo do backend
    await _load();
  }

  void _abrirDetalhe(ExameResumo a) async {
    final profile = await Session.getProfile();
    if (!mounted || profile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ExameDetalheSheet(
        repo: _repo,
        idMatricula: profile.id,
        numero: a.numero,
        resumo: a,
        onPdfNoApp: _openPdfNoApp,
        // vindo da lista de "liberadas": força o botão habilitado
        forcePodeImprimir: true,
      ),
    ).then((_) => _load());
  }

  void _verTodas() async {
    final profile = await Session.getProfile();
    if (!mounted || profile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _LiberadasModal(
        repo: _repo,
        idMatricula: profile.id,
        onPdfNoApp: _openPdfNoApp,
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SectionCard(
        title: 'Autorizações de Exames (liberadas)',
        child: LoadingPlaceholder(height: 76),
      );
    }
    if (_error != null) {
      return SectionCard(
        title: 'Autorizações de Exames (liberadas)',
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (_itens.isEmpty) return const SizedBox.shrink();

    final first = _itens.first;

    return SectionCard(
      title: 'Autorizações de Exames (liberadas)',
      trailing: TextButton(onPressed: _verTodas, child: const Text('Ver todas')),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
        leading: const Icon(Icons.check_circle_outline),
        title: Text(
          '${first.paciente} • ${first.prestador}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(first.dataHora),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _abrirDetalhe(first),
      ),
    );
  }
}

class _LiberadasModal extends StatefulWidget {
  final ExamesRepository repo;
  final int idMatricula;
  final Future<void> Function(int numero)? onPdfNoApp;

  const _LiberadasModal({
    required this.repo,
    required this.idMatricula,
    this.onPdfNoApp,
  });

  @override
  State<_LiberadasModal> createState() => _LiberadasModalState();
}

class _LiberadasModalState extends State<_LiberadasModal> {
  bool _loading = true;
  String? _error;
  List<ExameResumo> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _rows = const []; });
    try {
      final rows = await widget.repo.listarLiberadas(idMatricula: widget.idMatricula, limit: 0);
      rows.sort((a, b) => b.dataHora.compareTo(a.dataHora));
      setState(() { _rows = rows; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Erro ao carregar.'; _loading = false; });
    }
  }

  void _abrirDetalhe(ExameResumo a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ExameDetalheSheet(
        repo: widget.repo,
        idMatricula: widget.idMatricula,
        numero: a.numero,
        resumo: a,
        onPdfNoApp: widget.onPdfNoApp,
        // vindo da lista de "liberadas": força o botão habilitado
        forcePodeImprimir: true,
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controller) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 5,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 10),
              const Text('Autorizações de Exames (liberadas)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_error != null)
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : (_rows.isEmpty)
                    ? const Center(child: Text('Nenhuma autorização liberada.'))
                    : ListView.builder(
                  controller: controller,
                  itemCount: _rows.length,
                  itemBuilder: (_, i) {
                    final a = _rows[i];
                    return ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(
                        '${a.paciente} • ${a.prestador}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(a.dataHora),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrirDetalhe(a),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
