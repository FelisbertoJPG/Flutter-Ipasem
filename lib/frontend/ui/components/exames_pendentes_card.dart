import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../common/config/app_config.dart';
import '../../../common/models/exame.dart';
import '../../../common/repositories/exames_repository.dart';
import '../../../common/services/dev_api.dart';
import '../../../common/services/session.dart';
import '../../../common/state/auth_events.dart';
import '../components/loading_placeholder.dart';
import '../components/section_card.dart';
import '../sheets/exame_detalhe_sheet.dart';

// NOVO: ring reutilizável
import 'ring_update.dart';

// Chave em SharedPreferences para snapshot anterior dos PENDENTES.
const _kPrevPendentesKey = 'exames_pendentes_prev_ids';

class ExamesPendentesCard extends StatefulWidget {
  const ExamesPendentesCard({super.key});

  @override
  State<ExamesPendentesCard> createState() => _ExamesPendentesCardState();
}

class _ExamesPendentesCardState extends State<ExamesPendentesCard> {
  late DevApi _api;
  late ExamesRepository _repo;
  bool _ready = false;

  bool _loading = true;
  String? _error;

  /// Lista atual exibida (pendentes).
  List<ExameResumo> _itens = const [];

  /// IDs (números) que sumiram entre última carga e a atual.
  /// Sinalizam “mudou de situação” (ex.: virou Liberada 'A' ou foi negada).
  List<int> _sumiram = const [];

  /// Snapshot anterior (para diff).
  Set<int> _prevIds = {};

  VoidCallback? _issuedListener;
  VoidCallback? _printedListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;

    final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
        ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');

    _api = DevApi(baseUrl);
    _repo = ExamesRepository(_api);

    // Auto-refresh quando uma autorização é emitida (issue) ou impressa (A->R)
    _issuedListener = () => Future.microtask(_load);
    _printedListener = () => Future.microtask(_load);
    AuthEvents.instance.lastIssued.addListener(_issuedListener!);
    AuthEvents.instance.lastPrinted.addListener(_printedListener!);

    _ready = true;
    _load();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _itens = const [];
      _sumiram = const [];
    });

    try {
      // Carrega snapshot anterior
      _prevIds = await _readPrevIds();

      final profile = await Session.getProfile();
      if (profile == null) {
        setState(() {
          _error = 'Faça login para ver seus exames.';
          _loading = false;
        });
        return;
      }

      // Busca pendentes (status 'P')
      final rows = await _repo.listarPendentes(
        idMatricula: profile.id,
        limit: 0,
      );

      // Calcula diffs
      final currentIds = rows.map((e) => e.numero).toSet();
      final disappeared = _prevIds.difference(currentIds).toList()..sort();
      final novos = currentIds.difference(_prevIds);

      // Ordena priorizando “novos em P”, depois por data/hora desc
      final ordered = List<ExameResumo>.from(rows);
      ordered.sort((a, b) {
        final aNovo = novos.contains(a.numero) ? 1 : 0;
        final bNovo = novos.contains(b.numero) ? 1 : 0;
        if (aNovo != bNovo) return bNovo.compareTo(aNovo);
        return b.dataHora.compareTo(a.dataHora);
      });

      // Persiste snapshot atual
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

  // Modal com TODAS as pendentes
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
      builder: (_) => _ExamesPendentesModal(
        repo: _repo,
        idMatricula: profile.id,
      ),
    ).then((_) => _load()); // refresh ao fechar
  }

  // Modal com “atualizações” (itens que sumiram de P)
  void _openModalAtualizacoes() async {
    final profile = await Session.getProfile();
    if (!mounted || profile == null) return;
    if (_sumiram.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AtualizacoesModal(
        repo: _repo,
        idMatricula: profile.id,
        numeros: _sumiram,
      ),
    ).then((_) => _load());
  }

  // Abre detalhe do primeiro item (atalho)
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
        title: 'Autorizações de Exames (pendentes)',
        child: LoadingPlaceholder(height: 76),
      );
    }

    if (_error != null) {
      return SectionCard(
        title: 'Autorizações de Exames (pendentes)',
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    // Quando não há pendentes, mas houve mudanças (ring/aviso)
    if (_itens.isEmpty) {
      if (_sumiram.isEmpty) return const SizedBox.shrink();
      return SectionCard(
        title: 'Autorizações de Exames',
        child: RingUpdateBanner(
          quantidade: _sumiram.length,
          onTap: _openModalAtualizacoes,
        ),
      );
    }

    // Há pendentes: mostra ring (se houver) + primeiro item
    return SectionCard(
      title: 'Autorizações de Exames (pendentes)',
      trailing: TextButton(
        onPressed: _openModalPendentes,
        child: const Text('Ver todos'),
      ),
      child: Column(
        children: [
          if (_sumiram.isNotEmpty)
            RingUpdateBanner(
              quantidade: _sumiram.length,
              onTap: _openModalAtualizacoes,
            ),
          InkWell(
            onTap: _openFirstItemDetail,
            child: _TileResumo(_itens.first),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TileResumo extends StatelessWidget {
  final ExameResumo a;
  const _TileResumo(this.a);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      dense: true,
      leading: const Icon(Icons.hourglass_empty_outlined),
      title: Text(
        '${a.paciente.isEmpty ? "Paciente" : a.paciente} • ${a.prestador.isEmpty ? "Prestador" : a.prestador}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(a.dataHora),
    );
  }
}

class _ExamesPendentesModal extends StatefulWidget {
  final ExamesRepository repo;
  final int idMatricula;

  const _ExamesPendentesModal({
    required this.repo,
    required this.idMatricula,
  });

  @override
  State<_ExamesPendentesModal> createState() => _ExamesPendentesModalState();
}

class _ExamesPendentesModalState extends State<_ExamesPendentesModal> {
  bool _loading = true;
  String? _error;
  List<ExameResumo> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = const [];
    });
    try {
      final rows = await widget.repo.listarPendentes(
        idMatricula: widget.idMatricula,
        limit: 0,
      );
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = kDebugMode ? 'Erro ao carregar: $e' : 'Erro ao carregar.';
        _loading = false;
      });
    }
  }

  void _openDetail(ExameResumo a) {
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
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controller) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 10),
              const Text(
                'Autorizações de Exames (pendentes)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_error != null)
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : (_rows.isEmpty)
                    ? const Center(child: Text('Nenhum exame pendente.'))
                    : ListView.builder(
                  controller: controller,
                  itemCount: _rows.length,
                  itemBuilder: (_, i) {
                    final a = _rows[i];
                    return ListTile(
                      leading: const Icon(Icons.hourglass_bottom),
                      title: Text(
                        '${a.paciente} • ${a.prestador}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  /// Nova heurística:
  /// - Primeiro buscamos TODAS as liberadas e montamos um Set<int>.
  /// - O número só é marcado como "liberada" se estiver nesse Set.
  /// - Ainda assim buscamos detalhe para abrir o sheet.
  Future<List<_StatusConsulta>> _load() async {
    // 1) Quais números estão de fato em "liberadas"?
    final libRows = await widget.repo.listarLiberadas(
      idMatricula: widget.idMatricula,
      limit: 0,
    );
    final liberadasSet = libRows.map((e) => e.numero).toSet();

    // 2) Monta a lista final
    final out = <_StatusConsulta>[];
    for (final n in widget.numeros) {
      try {
        ExameDetalhe? dados;
        try {
          dados = await widget.repo.consultarDetalhe(
            numero: n,
            idMatricula: widget.idMatricula,
          );
        } catch (_) {
          dados = null;
        }

        final isLiberada = liberadasSet.contains(n);

        out.add(_StatusConsulta(
          numero: n,
          liberada: isLiberada,
          dados: dados,
        ));
      } catch (e) {
        out.add(_StatusConsulta(
          numero: n,
          liberada: false,
          erro: e.toString(),
        ));
      }
    }
    // Ordena: liberadas primeiro
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
        // se não liberada, pode não haver resumo; o sheet mostra aviso
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
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 10),
              Text(
                'Atualizações de situação (${widget.numeros.length} $plural)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<_StatusConsulta>>(
                  future: _future,
                  builder: (_, snap) {
                    if (!snap.hasData) {
                      if (snap.hasError) {
                        return Center(
                          child: Text('Erro: ${snap.error}', style: const TextStyle(color: Colors.red)),
                        );
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
                            : (s.erro != null
                            ? 'Falha ao consultar'
                            : 'Atualizada — toque para verificar');
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

class _StatusConsulta {
  final int numero;
  final bool liberada;
  final ExameDetalhe? dados;
  final String? erro;

  _StatusConsulta({
    required this.numero,
    required this.liberada,
    this.dados,
    this.erro,
  });
}
