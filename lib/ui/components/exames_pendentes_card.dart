// lib/ui/cards/exames_pendentes_card.dart  (ou onde você colocou)

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import '../../services/dev_api.dart';
import '../../services/session.dart';
import '../../config/app_config.dart';

import '../../repositories/exames_repository.dart';
// ⬇️ troque o model importado
import '../../models/exame.dart'; // <-- era ../../models/autorizacao.dart

import '../components/section_card.dart';
import '../components/loading_placeholder.dart';

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
        setState(() { _error = 'Faça login para ver seus exames.'; _loading = false; });
        return;
      }
      final rows = await _repo.listarPendentes(idMatricula: profile.id, limit: 1);
      setState(() { _itens = rows; _loading = false; });
    } catch (e) {
      setState(() {
        _error = kDebugMode ? 'Erro ao carregar pendentes: $e' : 'Erro ao carregar pendentes.';
        _loading = false;
      });
    }
  }

  void _openModal() async {
    final profile = await Session.getProfile();
    if (!mounted || profile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ExamesPendentesModal(repo: _repo, idMatricula: profile.id),
    ).then((_) => _load()); // refresh ao fechar
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
    if (_itens.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: 'Autorizações de Exames (pendentes)',
      trailing: TextButton(onPressed: _openModal, child: const Text('Ver todos')),
      child: Column(
        children: [
          _TileResumo(_itens.first),
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
  const _ExamesPendentesModal({required this.repo, required this.idMatricula});

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
    setState(() { _loading = true; _error = null; _rows = const []; });
    try {
      final rows = await widget.repo.listarPendentes(
        idMatricula: widget.idMatricula,
        limit: 0 , // sem limite
      );
      setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      setState(() { _error = kDebugMode ? '$e' : 'Erro ao carregar.'; _loading = false; });
    }
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
              Container(width: 40, height: 5,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 10),
              const Text('Autorizações de Exames (pendentes)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(a.dataHora),
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
