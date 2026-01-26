// lib/frontend/views/components/exames_comp/exames_negadas_card.dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:ipasemnhdigital/frontend/views/components/cards/section_card.dart';

import '../../../../common/models/exame.dart';
import '../../../../common/repositories/exames_repository.dart';
import '../../../../common/services/session.dart';
import '../../sheets/exame_detalhe_sheet.dart';
import '../loading_placeholder.dart';

class ExamesNegadasCard extends StatefulWidget {
  const ExamesNegadasCard({super.key});

  @override
  State<ExamesNegadasCard> createState() => _ExamesNegadasCardState();
}

class _ExamesNegadasCardState extends State<ExamesNegadasCard> {
  late ExamesRepository _repo;
  bool _ready = false;

  bool _loading = true;
  String? _error;
  List<ExameResumo> _rows = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;

    // Usa a base/config atual via ApiRouter/AppConfig internamente
    _repo = ExamesRepository.fromContext(context);

    _ready = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = const [];
    });

    try {
      final profile = await Session.getProfile();
      if (profile == null) {
        setState(() {
          _loading = false;
          _error = 'Faça login para ver suas autorizações.';
        });
        return;
      }

      // Traz até 5 negadas para a Home
      final rows = await _repo.listarNegadas(
        idMatricula: profile.id,
        limit: 5,
      );

      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error =
        kDebugMode ? 'Erro ao carregar negadas: $e' : 'Erro ao carregar.';
      });
    }
  }

  void _openAll() async {
    final profile = await Session.getProfile();
    if (!mounted || profile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          _ExamesNegadasModal(repo: _repo, idMatricula: profile.id),
    ).then((_) => _load());
  }

  void _openDetail(ExameResumo a) async {
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
        resumo: a, // pode não ter detalhe/permitir impressão; o sheet lida com isso
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SectionCard(
        title: 'Autorizações Negadas',
        child: LoadingPlaceholder(height: 76),
      );
    }

    if (_error != null) {
      return SectionCard(
        title: 'Autorizações Negadas',
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_rows.isEmpty) {
      // Não exibe nada quando não há negadas
      return const SizedBox.shrink();
    }

    // Mostra apenas a primeira (mais recente) + botão "Ver todas"
    final a = _rows.first;

    return SectionCard(
      title: 'Autorizações Negadas',
      trailing: TextButton(
        onPressed: _openAll,
        child: const Text('Ver todas'),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: const Icon(Icons.block, color: Colors.red),
            title: Text(
              '${a.paciente.isEmpty ? "Paciente" : a.paciente} • '
                  '${a.prestador.isEmpty ? "Prestador" : a.prestador}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(a.dataHora),
            onTap: () => _openDetail(a),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ExamesNegadasModal extends StatefulWidget {
  final ExamesRepository repo;
  final int idMatricula;

  const _ExamesNegadasModal({
    required this.repo,
    required this.idMatricula,
  });

  @override
  State<_ExamesNegadasModal> createState() => _ExamesNegadasModalState();
}

class _ExamesNegadasModalState extends State<_ExamesNegadasModal> {
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
      final rows = await widget.repo.listarNegadas(
        idMatricula: widget.idMatricula,
        limit: 0, // todas (sem limite) no modal
      );
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error =
        kDebugMode ? 'Erro ao carregar: $e' : 'Erro ao carregar.';
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
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Autorizações Negadas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_error != null)
                    ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
                    : (_rows.isEmpty)
                    ? const Center(
                  child: Text('Nenhuma autorização negada.'),
                )
                    : ListView.separated(
                  controller: controller,
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final a = _rows[i];
                    return ListTile(
                      leading: const Icon(
                        Icons.block,
                        color: Colors.red,
                      ),
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
