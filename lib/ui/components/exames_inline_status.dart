// lib/ui/components/exames_inline_status.dart
import 'package:flutter/material.dart';

import '../../services/api_router.dart';
import '../../services/session.dart';
import '../../repositories/exames_repository.dart';
import '../../models/exame.dart';
import '../../state/auth_events.dart';

class ExamesInlineStatusList extends StatefulWidget {
  const ExamesInlineStatusList({
    super.key,
    this.take = 3,
    this.onTap,
  });

  /// Quantos itens exibir (apenas 'P' e 'A', mais recentes primeiro).
  final int take;

  /// Callback opcional ao tocar no item.
  final void Function(ExameResumo exame)? onTap;

  @override
  State<ExamesInlineStatusList> createState() => _ExamesInlineStatusListState();
}

class _ExamesInlineStatusListState extends State<ExamesInlineStatusList> {
  late ExamesRepository _repo;
  bool _loading = false;
  List<ExameResumo> _items = const [];

  // listeners para auto-refresh
  VoidCallback? _onIssued;
  VoidCallback? _onPrinted;
  VoidCallback? _onStatusChanged;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _onIssued = () => _refreshThrottle();
    AuthEvents.instance.lastIssued.addListener(_onIssued!);

    _onPrinted = () => _refreshThrottle();
    AuthEvents.instance.lastPrinted.addListener(_onPrinted!);

    _onStatusChanged = () => _refreshThrottle();
    AuthEvents.instance.exameStatusChanged.addListener(_onStatusChanged!);

    // Inicializa o repositório já com o DevApi configurado via ApiRouter
    _repo = ExamesRepository(ApiRouter.client());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_items.isEmpty && !_loading) {
      _load();
    }
  }

  @override
  void dispose() {
    if (_onIssued != null) {
      AuthEvents.instance.lastIssued.removeListener(_onIssued!);
    }
    if (_onPrinted != null) {
      AuthEvents.instance.lastPrinted.removeListener(_onPrinted!);
    }
    if (_onStatusChanged != null) {
      AuthEvents.instance.exameStatusChanged.removeListener(_onStatusChanged!);
    }
    super.dispose();
  }

  void _refreshThrottle() {
    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!) < const Duration(seconds: 2)) {
      return;
    }
    _lastRefresh = now;
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final profile = await Session.getProfile();
      if (profile == null) {
        setState(() => _items = const []);
      } else {
        final rows = await _repo.listarUltimosAP(
          idMatricula: profile.id,
          limit: widget.take,
        );
        if (!mounted) return;
        setState(() => _items = rows);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sem moldura: apenas cabeçalho + lista
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: const [
            Icon(Icons.monitor_heart, size: 20, color: Color(0xFF344054)),
            SizedBox(width: 8),
            Text('Exames', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 10),
        if (_loading) const _SkeletonList()
        else if (_items.isEmpty)
          const _Empty()
        else
          Column(
            children: [
              for (int i = 0; i < _items.length; i++) ...[
                _ExamTile(
                  exame: _items[i],
                  onTap: widget.onTap == null
                      ? null
                      : () => widget.onTap!(_items[i]),
                ),
                if (i != _items.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
              ],
            ],
          ),
      ],
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    Widget line() => Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 12,
                width: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Column(
      children: [
        line(),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        line(),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        line(),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Sem exames no momento.',
      style: TextStyle(color: Color(0xFF667085), fontSize: 12.5),
    );
  }
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({required this.exame, this.onTap});
  final ExameResumo exame;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final st = (exame.status ?? '').toUpperCase();
    final isLiberado = st == 'A';
    final chipColor = isLiberado ? const Color(0xFF12B76A) : const Color(0xFF7A5AF8);
    final chipBg    = isLiberado ? const Color(0xFFEFFDF5) : const Color(0xFFF1EFFE);
    final chipText  = isLiberado ? 'Liberado' : 'Pendente';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.biotech_outlined, size: 20, color: Color(0xFF344054)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${exame.numero} • ${exame.paciente}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exame.prestador,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF667085), fontSize: 12.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      exame.dataHora.isEmpty ? '—' : exame.dataHora,
                      style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chipText,
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
            ],
          ),
        ),
      ),
    );
  }
}
