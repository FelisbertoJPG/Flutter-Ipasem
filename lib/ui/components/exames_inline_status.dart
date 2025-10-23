import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/dev_api.dart';
import '../../services/session.dart';
import '../../repositories/exames_repository.dart';
import '../../models/exame.dart';
import '../../state/auth_events.dart';
import '../sheets/exame_detalhe_sheet.dart';

class ExamesInlineStatusList extends StatefulWidget {
  const ExamesInlineStatusList({super.key, this.take = 3});

  /// Quantos itens mostrar (mais recentes)
  final int take;

  @override
  State<ExamesInlineStatusList> createState() => _ExamesInlineStatusListState();
}

class _ExamesInlineStatusListState extends State<ExamesInlineStatusList> {
  bool _ready = false;
  bool _loading = true;
  String? _error;

  late DevApi _api;
  late ExamesRepository _repo;

  List<ExameResumo> _rows = const [];

  // listeners do “ring”
  VoidCallback? _onIssued;
  VoidCallback? _onStatus;

  @override
  void initState() {
    super.initState();
    // quando algo muda no ring (nova emissão / mudança de status), recarrega
    _onIssued = () => _fetch();
    _onStatus = () => _fetch();
    AuthEvents.instance.lastIssued.addListener(_onIssued!);
    AuthEvents.instance.exameStatusChanged.addListener(_onStatus!);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;

    final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
        ?? const String.fromEnvironment('API_BASE', defaultValue: 'https://assistweb.ipasemnh.com.br');

    _api = DevApi(baseUrl);
    _repo = ExamesRepository(_api);
    _ready = true;

    _fetch();
  }

  @override
  void dispose() {
    if (_onIssued != null) {
      AuthEvents.instance.lastIssued.removeListener(_onIssued!);
    }
    if (_onStatus != null) {
      AuthEvents.instance.exameStatusChanged.removeListener(_onStatus!);
    }
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; _rows = const []; });

    try {
      final profile = await Session.getProfile();
      if (!mounted) return;

      if (profile == null) {
        setState(() { _loading = false; _rows = const []; });
        return;
      }

      // Busca tudo numa tacada só e filtra A|P
      final res = await _api.postAction('exames_historico', data: {
        'id_matricula': profile.id,
      });

      final body = (res.data as Map?) ?? const {};
      if (body['ok'] != true) {
        setState(() { _loading = false; _rows = const []; });
        return;
      }

      final rows = ((body['data'] as Map?)?['rows'] as List?) ?? const [];
      final parsed = rows
          .cast<Map>()
          .map((m) => ExameResumo.fromJson(m.cast<String, dynamic>()))
          .where((e) {
        final st = (e.status ?? '').trim().toUpperCase();
        return st == 'A' || st == 'P'; // só liberadas ou pendentes
      })
          .toList();

      // ordena por data/hora (desc)
      DateTime _parse(String s) {
        final t = s.trim();
        if (t.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
        // aceita "dd/MM/yyyy HH:mm" ou só "dd/MM/yyyy"
        final parts = t.split(' ');
        final d = parts.first;
        final p = d.split('/');
        if (p.length != 3) return DateTime.fromMillisecondsSinceEpoch(0);
        final dd = int.tryParse(p[0]) ?? 1;
        final mm = int.tryParse(p[1]) ?? 1;
        var yy  = int.tryParse(p[2]) ?? 1970;
        if (yy < 100) yy += 2000;
        int hh = 0, mi = 0;
        if (parts.length > 1) {
          final h = parts[1].split(':');
          hh = int.tryParse(h[0]) ?? 0;
          mi = (h.length > 1) ? int.tryParse(h[1]) ?? 0 : 0;
        }
        return DateTime(yy, mm, dd, hh, mi);
      }

      parsed.sort((a, b) => _parse(b.dataHora).compareTo(_parse(a.dataHora)));

      final limited = (widget.take > 0) ? parsed.take(widget.take).toList() : parsed;

      setState(() {
        _rows = limited;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar exames.';
      });
    }
  }

  Future<void> _openDetail(ExameResumo a) async {
    final profile = await Session.getProfile();
    if (!mounted || profile == null) return;

    await showModalBottomSheet(
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

    // volta e recarrega (caso tenha “virado” R etc.)
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // deixa que o card pai mostre o esqueleto; aqui não ocupa espaço
      return const SizedBox.shrink();
    }
    if (_error != null || _rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Text('Exames', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (int i = 0; i < _rows.length; i++) ...[
          _ExamTile(item: _rows[i], onTap: () => _openDetail(_rows[i])),
          if (i != _rows.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
        ],
      ],
    );
  }
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({required this.item, this.onTap});
  final ExameResumo item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final st = (item.status ?? '').trim().toUpperCase();
    final statusLabel = (st == 'A') ? 'Liberado' : (st == 'P') ? 'Pendente' : st;
    final statusColor = (st == 'A') ? const Color(0xFF067647) : const Color(0xFF7F56D9);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.biotech_outlined, size: 22, color: Color(0xFF344054)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${item.numero} • $statusLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.paciente} • ${item.prestador}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF667085), fontSize: 12.5, height: 1.15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.dataHora,
                      style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 12, height: 1.1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withOpacity(0.25)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
            ],
          ),
        ),
      ),
    );
  }
}
