import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/components/exames_liberados_card.dart';

import '../root_nav_shell.dart';
import '../ui/app_shell.dart';
import '../ui/components/exames_pendentes_card.dart';
import '../ui/components/section_card.dart';
import '../ui/components/quick_actions.dart';
import '../ui/components/services_visitor.dart';
import '../ui/widgets/history_list.dart';
import '../ui/utils/webview_warmup.dart';
import '../ui/utils/service_launcher.dart';
import '../ui/utils/print_helpers.dart'; // openPreviewFromNumero

import '../models/reimpressao.dart';
import '../controllers/home_servicos_controller.dart';
import '../ui/components/reimp_action_sheet.dart';
import '../ui/components/reimp_detalhes_sheet.dart';

import '../state/auth_events.dart'; // <=== ouvimos emits para auto-refresh

import 'login_screen.dart';
import 'autorizacao_medica_screen.dart';
import 'autorizacao_odontologica_screen.dart';
import 'autorizacao_exames_screen.dart'; // <<< NOVA TELA

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

  List<HistoryItem> _historico = const [];
  List<ReimpressaoResumo> _histRows = const [];

  late final ServiceLauncher launcher = ServiceLauncher(context, takePrewarmed);
  HomeServicosController? _controller;

  VoidCallback? _issuedListener;
  VoidCallback? _printedListener; // <=== NOVO

  @override
  void initState() {
    super.initState();
    warmupInit();

    // Quando sair uma nova autorização, recarrega o histórico aqui
    _issuedListener = () {
      Future.microtask(_refreshAfterIssue);
    };
    AuthEvents.instance.lastIssued.addListener(_issuedListener!);

    // Quando a PRIMEIRA impressão acontecer (A->R), recarrega o histórico
    _printedListener = () {
      Future.microtask(_refreshAfterPrint);
    };
    AuthEvents.instance.lastPrinted.addListener(_printedListener!);

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

    // Garante que o número já esteja visível no histórico de reimpressão.
    if (_controller != null) {
      await _controller!.waitUntilInHistorico(numero);
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
    super.dispose();
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

        // pega o nome do titular para fallback do "paciente"
        final titularNome = await _controller!.profileName();

        final rows = await _controller!.loadHistorico();
        _histRows = rows;

        _historico = rows.map((h) {
          // paciente com fallback (quando é o titular, a API pode vir vazio)
          final paciente = (h.paciente.trim().isNotEmpty)
              ? h.paciente.trim()
              : (titularNome?.trim() ?? '');

          // título: se tiver prestador usa, senão cai para paciente, e por fim nº
          final titulo = h.prestadorExec.isNotEmpty
              ? h.prestadorExec
              : (paciente.isNotEmpty ? paciente : 'Autorização ${h.numero}');

          // subtítulo: data/hora + • paciente (se houver)
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

  // ====== AÇÕES RÁPIDAS (logado) ======
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
      // <<< NOVO BOTÃO
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
      // >>>
      QuickActionItem(
        id: 'carteirinha',
        label: 'Carteirinha Digital',
        icon: FontAwesomeIcons.idCard,
        onTap: () => launcher.openUrl(
          HomeServicos._loginUrl,
          'Carteirinha Digital',
        ),
        audience: QaAudience.loggedIn,
        requiresLogin: false,
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

  // ====== ACTIONS ======
  Future<void> _onTapHistorico(ReimpressaoResumo a) async {
    if (!mounted) return;

    final action = await showReimpActionSheet(context, a);
    if (action == null) return;

    switch (action) {
      case ReimpAction.detalhes:
        await _showDetalhes(a.numero, pacienteFallback: a.paciente.isNotEmpty ? a.paciente : null);
        break;
      case ReimpAction.pdfLocal:
        await openPreviewFromNumero(context, a.numero); // helper centralizado
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

  // ====== VISITOR VIEW ======
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

  // ====== MEMBER VIEW ======
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
        const ExamesLiberadosCard(),
        const SizedBox(height: 12),
        const ExamesPendentesCard(),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Histórico de Autorizações',
          child: HistoryList(
            loading: _loading,
            isLoggedIn: true,
            items: _historico,
            onSeeAll: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Implementar tela de histórico completo.')),
              );
            },
          ),
        ),
      ],
    );
  }
}
