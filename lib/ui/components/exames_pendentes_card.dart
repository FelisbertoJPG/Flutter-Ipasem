// lib/ui/components/exames_pendentes_card.dart
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/exame.dart';
import '../../repositories/exames_repository.dart';
import '../../services/dev_api.dart';
import '../../services/session.dart';

import '../components/section_card.dart';
import '../components/loading_placeholder.dart';
import '../sheets/exame_detalhe_sheet.dart';

// Chave em SharedPreferences onde guardamos o snapshot anterior dos pendentes.
const _kPrevPendentesKey = 'exames_pendentes_prev_ids';

class ExamesPendentesCard extends StatefulWidget {
  const ExamesPendentesCard({super.key});

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

      // Busca pendentes
      final rows = await _repo.listarPendentes(idMatricula: profile.id, limit: 0);

      // Calcula diffs
      final currentIds = rows.map((e) => e.numero).toSet();
      final disappeared = _prevIds.difference(currentIds).toList()..sort();
      final novos = currentIds.difference(_prevIds);

      // Ordena priorizando novos, depois por data/hora desc
      final ordered = List<ExameResumo>.from(rows);
      ordered.sort((a, b) {
        final aNovo = novos.contains(a.numero) ? 1 : 0;
        final bNovo = novos.contains(b.numero) ? 1 : 0;
        if (aNovo != bNovo) return bNovo.compareTo(aNovo);
        return (b.dataHora).compareTo(a.dataHora);
      });

      await _writePrevIds(currentIds);

      setState(() {
        _itens = ordered;
        _sumiram = disappeared;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = kDebugMode ? 'Erro ao carregar pendentes: $e' : 'Erro ao carregar pendentes.';
        _loading = false;
      });
    }
  }

  Future<Set<int>> _readPrevIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrevPendentesKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((v) => v > 0)
            .toSet();
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _writePrevIds(Set<int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrevPendentesKey, jsonEncode(ids.toList()));
    } catch (_) {
      // silencioso
    }
  }

  // Abra o modal com a lista completa de pendentes
  void _openModalPendentes() async {
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
      ),
    ).then((_) => _load()); // refresh após fechar
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
        numeros: _sumiram,
      ),
    ).then((_) => _load());
  }

  // Abre diretamente o detalhe do primeiro item
  void _openFirstItemDetail() async {
    final profile = await Session.getProfile();
    if (!mounted || profile == null || _itens.isEmpty) return;

    final a = _itens.first;
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
      ),
    );
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

  const _ExamesPendentesModal({
    required this.repo,
    required this.idMatricula,
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
      ),
    );
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
                      onTap: () => _openDetail(a),
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

class _AtualizacoesModal extends StatefulWidget {
  final ExamesRepository repo;
  final int idMatricula;
  final List<int> numeros;

  const _AtualizacoesModal({
    required this.repo,
    required this.idMatricula,
    required this.numeros,
  });

  @override
  State<_AtualizacoesModal> createState() => _AtualizacoesModalState();
}

class _AtualizacoesModalState extends State<_AtualizacoesModal> {
  late Future<List<_StatusConsulta>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_StatusConsulta>> _load() async {
    final out = <_StatusConsulta>[];
    for (final n in widget.numeros) {
      try {
        ExameDetalhe? dados;
        try {
          dados = await widget.repo.consultarDetalhe(numero: n, idMatricula: widget.idMatricula);
        } catch (_) {
          dados = null;
        }
        out.add(_StatusConsulta(
          numero: n,
          liberada: dados != null,
          dados: dados,
        ));
      } catch (e) {
        out.add(_StatusConsulta(numero: n, liberada: false, erro: e.toString()));
      }
    }
    out.sort((a, b) => (b.liberada ? 1 : 0).compareTo(a.liberada ? 1 : 0));
    return out;
  }

  void _openDetail(_StatusConsulta s) {
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
        numero: s.numero,
        // se não liberada, não temos resumo; o sheet mostra aviso
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plural = widget.numeros.length > 1 ? 'autorizações' : 'autorização';

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controller) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 10),
              Text('Atualizações de situação (${widget.numeros.length} $plural)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<_StatusConsulta>>(
                  future: _future,
                  builder: (_, snap) {
                    if (!snap.hasData) {
                      if (snap.hasError) {
                        return Center(child: Text('Erro: ${snap.error}', style: const TextStyle(color: Colors.red)));
                      }
                      return const Center(child: CircularProgressIndicator());
                    }
                    final rows = snap.data!;
                    if (rows.isEmpty) return const Center(child: Text('Nada a mostrar.'));
                    return ListView.builder(
                      controller: controller,
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final s = rows[i];
                        final subt = s.liberada
                            ? 'Liberada para impressão'
                            : (s.erro != null ? 'Falha ao consultar' : 'Ainda não liberada / negada');
                        return ListTile(
                          leading: Icon(s.liberada ? Icons.check_circle_outline : Icons.info_outline),
                          title: Text('Autorização nº ${s.numero}'),
                          subtitle: Text(subt, maxLines: 2),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openDetail(s),
                        );
                      },
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
