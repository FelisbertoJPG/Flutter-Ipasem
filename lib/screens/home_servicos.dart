// lib/screens/home_servicos.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../root_nav_shell.dart';
import '../ui/app_shell.dart';
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

import '../state/auth_events.dart';

import 'login_screen.dart';
import 'autorizacao_medica_screen.dart';
import 'autorizacao_odontologica_screen.dart';

class HomeServicos extends StatefulWidget {
  const HomeServicos({super.key});

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

  // Listener para eventos de emissão
  VoidCallback? _authListener;

  @override
  void initState() {
    super.initState();
    warmupInit();

    // Quando sair uma nova autorização, tenta esperar o backend refletir no histórico e recarrega
    _authListener = () {
      Future.microtask(_refreshAfterIssue);
    };
    AuthEvents.instance.lastIssued.addListener(_authListener!);

    _bootstrap();
  }

  @override
  void dispose() {
    if (_authListener != null) {
      AuthEvents.instance.lastIssued.removeListener(_authListener!);
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
        final rows = await _controller!.loadHistorico();
        _histRows = rows;

        _historico = rows.map((h) {
          final titulo = h.prestadorExec.isNotEmpty ? h.prestadorExec : 'Autorização ${h.numero}';
          final sub = [
            if (h.dataEmissao.isNotEmpty && h.horaEmissao.isNotEmpty)
              '${h.dataEmissao} • ${h.horaEmissao}'
            else if (h.dataEmissao.isNotEmpty)
              h.dataEmissao,
            if (h.paciente.isNotEmpty) '• ${h.paciente}',
          ].join(' ');
          return HistoryItem(title: titulo, subtitle: sub, onTap: () => _onTapHistorico(h));
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

  // Após emissão, aguarda o histórico refletir a nova ordem e recarrega
  Future<void> _refreshAfterIssue() async {
    final numero = AuthEvents.instance.lastIssued.value;
    if (!mounted || numero == null) return;

    if (_controller != null) {
      // requer o método waitUntilInHistorico no controller
      try {
        await _controller!.waitUntilInHistorico(numero);
      } catch (_) {
        // se o método não existir/der erro, segue para o bootstrap mesmo assim
      }
    }

    if (!mounted) return;
    await _bootstrap();
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
