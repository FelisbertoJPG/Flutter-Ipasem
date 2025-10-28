// lib/screens/home_servicos.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../root_nav_shell.dart';
import '../ui/app_shell.dart';

import '../ui/components/exames_pendentes_card.dart';
import '../ui/components/exames_liberados_card.dart';
import '../ui/components/exames_negadas_card.dart';
import '../ui/components/section_card.dart';
import '../ui/components/quick_actions.dart';
import '../ui/components/services_visitor.dart';
import '../ui/widgets/history_list.dart';

import '../ui/utils/webview_warmup.dart';
import '../ui/utils/service_launcher.dart';
import '../ui/utils/print_helpers.dart';

import '../models/reimpressao.dart';
import '../controllers/home_servicos_controller.dart';
import '../ui/components/reimp_action_sheet.dart';
import '../ui/components/reimp_detalhes_sheet.dart';

import '../state/auth_events.dart';

// telas
import 'login_screen.dart';
import 'autorizacao_medica_screen.dart';
import 'autorizacao_odontologica_screen.dart';
import 'autorizacao_exames_screen.dart';
import 'historico_autorizacoes_screen.dart';

// sessão/perfil (para obter a matrícula)
import '../services/session.dart';

// sheet da carteirinha
import '../ui/sheets/card_sheet.dart';

class HomeServicos extends StatefulWidget {
  const HomeServicos({super.key});

  static const String _prefsKeyCpf = 'saved_cpf';
  static const String _loginUrl = 'https://assistweb.ipasemnh.com.br/site/login';
  static const String _siteUrl  = 'https://www.ipasemnh.com.br/home';

  @override
  State<HomeServicos> createState() => _HomeServicosState();
}

class _HomeServicosState extends State<HomeServicos> with WebViewWarmup {
  bool _loading = true;
  bool _isLoggedIn = false;

  int? _matricula; // usada para emissão da carteirinha

  List<HistoryItem> _historico = const [];
  List<ReimpressaoResumo> _histRows = const [];

  late final ServiceLauncher launcher = ServiceLauncher(context, takePrewarmed);
  HomeServicosController? _controller;

  VoidCallback? _issuedListener;
  VoidCallback? _printedListener;

  // refresh quando o poller sinaliza mudança de status
  VoidCallback? _statusChangedListener;
  DateTime? _lastAutoRefresh;

  @override
  void initState() {
    super.initState();
    warmupInit();

    _issuedListener = () => Future.microtask(_refreshAfterIssue);
    AuthEvents.instance.lastIssued.addListener(_issuedListener!);

    _printedListener = () => Future.microtask(_refreshAfterPrint);
    AuthEvents.instance.lastPrinted.addListener(_printedListener!);

    _statusChangedListener = () => Future.microtask(_refreshAfterStatusChange);
    AuthEvents.instance.exameStatusChanged.addListener(_statusChangedListener!);

    _bootstrap();
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

  // chamado quando o poller emite AuthEvents.exameStatusChanged
  Future<void> _refreshAfterStatusChange() async {
    final evt = AuthEvents.instance.exameStatusChanged.value;
    if (!mounted || evt == null) return;

    // throttle simples para evitar cascata de refresh
    final now = DateTime.now();
    if (_lastAutoRefresh != null &&
        now.difference(_lastAutoRefresh!) < const Duration(seconds: 2)) {
      return;
    }
    _lastAutoRefresh = now;

    if (_controller != null) {
      await _controller!.waitUntilInHistorico(evt.numero);
    }
    if (!mounted) return;

    await _bootstrap();
  }

  @override
  void dispose() {
    if (_issuedListener != null) {
      AuthEvents.instance.lastIssued.removeListener(_issuedListener!);
    }
    if (_printedListener != null) {
      AuthEvents.instance.lastPrinted.removeListener(_printedListener!);
    }
    if (_statusChangedListener != null) {
      AuthEvents.instance.exameStatusChanged.removeListener(_statusChangedListener!);
    }
    super.dispose();
  }

  DateTime _parseDateTime(String d, String h) {
    final ds = d.trim();
    final hs = h.trim();

    if (ds.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);

    // 1) ISO-like: yyyy-MM-dd (opcional HH:mm[:ss])
    if (ds.contains('-')) {
      final hh = hs.isEmpty
          ? '00:00:00'
          : (hs.split(':').length == 2 ? '${hs}:00' : hs); // garante segundos
      final iso = '${ds}T$hh';
      final isoParsed = DateTime.tryParse(iso);
      if (isoParsed != null) return isoParsed;
    }

    // 2) Brasileiro: dd/MM/yyyy (opcional HH:mm[:ss])
    if (ds.contains('/')) {
      try {
        final parts = ds.split('/');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]) ?? 1;
          final mon = int.tryParse(parts[1]) ?? 1;
          var yr = int.tryParse(parts[2]) ?? 1970;
          if (yr < 100) yr += 2000;
          final t = hs.isEmpty ? '00:00' : hs;
          final tp = t.split(':');
          final hh = int.tryParse(tp[0]) ?? 0;
          final mm = (tp.length > 1) ? int.tryParse(tp[1]) ?? 0 : 0;
          final ss = (tp.length > 2) ? int.tryParse(tp[2]) ?? 0 : 0;
          return DateTime(yr, mon, day, hh, mm, ss);
        }
      } catch (_) {/* fallback abaixo */}
    }

    // 3) Último recurso
    final fallback = DateTime.tryParse(ds);
    return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    _historico = const [];
    _histRows  = const [];

    if (_isLoggedIn) {
      try {
        _controller = await HomeServicosController.init(context);

        // obtém matrícula do perfil persistido na sessão
        try {
          final prof = await Session.getProfile();
          _matricula = prof?.id;
        } catch (_) {
          _matricula = null;
        }

        final titularNome = await _controller!.profileName();
        final rows = await _controller!.loadHistorico();

        // Ordena por data/hora (mais recentes primeiro)
        rows.sort((a, b) {
          final ta = _parseDateTime(a.dataEmissao, a.horaEmissao);
          final tb = _parseDateTime(b.dataEmissao, b.horaEmissao);
          return tb.compareTo(ta); // mais recente primeiro
        });

        // Limita às 5 mais recentes depois de ordenar
        final top5 = rows.take(5).toList();
        _histRows  = top5;

        _historico = top5.map((h) {
          final paciente = (h.paciente.trim().isNotEmpty)
              ? h.paciente.trim()
              : (titularNome?.trim() ?? '');

          final titulo = h.prestadorExec.isNotEmpty
              ? h.prestadorExec
              : (paciente.isNotEmpty ? paciente : 'Autorização ${h.numero}');

          final subParts = <String>[];
          if (h.dataEmissao.isNotEmpty && h.horaEmissao.isNotEmpty) {
            subParts.add('${h.dataEmissao} • ${h.horaEmissao}');
          } else if (h.dataEmissao.isNotEmpty) {
            subParts.add(h.dataEmissao);
          }
          if (paciente.isNotEmpty) subParts.add('• $paciente');

          final sub = subParts.join(' ');

          return HistoryItem(
            title: titulo,
            subtitle: sub,
            onTap: () => _onTapHistorico(h),
          );
        }).toList();
      } catch (e) {
        _historico = const [];
        _histRows  = const [];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao carregar histórico: $e')),
          );
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  List<QuickActionItem> _loggedActions() {
    return [
      QuickActionItem(
        id: 'aut_med',
        label: 'Autorização Médica',
        icon: FontAwesomeIcons.stethoscope,
        onTap: () {
          final scope = RootNavShell.maybeOf(context);
          if (scope != null) {
            scope.pushInServicos('autorizacao-medica');
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AutorizacaoMedicaScreen()),
            );
          }
        },
        audience: QaAudience.loggedIn,
        requiresLogin: false,
      ),
      QuickActionItem(
        id: 'aut_odo',
        label: 'Autorização Odontológica',
        icon: FontAwesomeIcons.tooth,
        onTap: () {
          final scope = RootNavShell.maybeOf(context);
          if (scope != null) {
            scope.pushInServicos('autorizacao-odontologica');
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AutorizacaoOdontologicaScreen()),
            );
          }
        },
        audience: QaAudience.loggedIn,
        requiresLogin: false,
      ),
      QuickActionItem(
        id: 'aut_exames',
        label: 'Autorização de Exames',
        icon: FontAwesomeIcons.xRay,
        onTap: () {
          final scope = RootNavShell.maybeOf(context);
          if (scope != null) {
            scope.pushInServicos('autorizacao-exames');
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AutorizacaoExamesScreen()),
            );
          }
        },
        audience: QaAudience.loggedIn,
        requiresLogin: false,
      ),
      QuickActionItem(
        id: 'carteirinha',
        label: 'Carteirinha Digital',
        icon: FontAwesomeIcons.idCard,
        onTap: () {
          final m = _matricula;
          if (m == null || m <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Não foi possível carregar a sua matrícula. Faça login novamente.')),
            );
            return;
          }
          // abre o sheet in-app; idDependente 0 = titular
          showCardSheet(context, matricula: m, idDependente: 0);
        },
        audience: QaAudience.loggedIn,
        requiresLogin: true,
      ),
      QuickActionItem(
        id: 'site',
        label: 'Site',
        icon: FontAwesomeIcons.globe,
        onTap: () => launcher.openUrl(HomeServicos._siteUrl, 'Site'),
        audience: QaAudience.all,
        requiresLogin: false,
      ),
    ];
  }

  Future<void> _onTapHistorico(ReimpressaoResumo a) async {
    if (!mounted) return;

    final action = await showReimpActionSheet(context, a);
    if (action == null) return;

    switch (action) {
      case ReimpAction.detalhes:
        await _showDetalhes(
          a.numero,
          pacienteFallback: a.paciente.isNotEmpty ? a.paciente : null,
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
        launcher.openUrl(HomeServicos._loginUrl, 'Reimpressão de Autorizações');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : (_isLoggedIn ? _buildMemberView() : _buildVisitorView());

    return AppScaffold(
      title: 'Serviços',
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [body],
        ),
      ),
    );
  }

  Widget _buildVisitorView() {
    return Column(
      children: [
        ServicesVisitors(
          onLoginTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Histórico de Autorizações',
          child: HistoryList(
            loading: _loading,
            isLoggedIn: false,
            items: const [],
            onSeeAll: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Faça login para acessar o histórico.')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMemberView() {
    return Column(
      children: [
        SectionCard(
          title: 'Serviços em destaque',
          child: QuickActions(
            title: null,
            items: _loggedActions(),
            isLoggedIn: true,
            onRequireLogin: null,
          ),
        ),
        const ExamesPendentesCard(),
        const SizedBox(height: 12),
        const ExamesLiberadosCard(),
        const SizedBox(height: 12),
        const ExamesNegadasCard(),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Histórico de Autorizações',
          child: HistoryList(
            loading: _loading,
            isLoggedIn: true,
            items: _historico, // já limitado a 5
            maxItems: 5,
            onSeeAll: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoricoAutorizacoesScreen()),
              );
            },
          ),
        ),
      ],
    );
  }
}
