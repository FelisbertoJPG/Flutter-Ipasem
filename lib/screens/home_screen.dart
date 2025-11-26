// lib/screens/home_screen.dart
import 'package:flutter/material.dart';

import '../core/formatters.dart';        // fmtData, fmtCpf
import '../core/models.dart';            // RequerimentoResumo, ComunicadoResumo
import '../data/session_store.dart';     // SessionStore
import '../repositories/dependents_repository.dart';
import '../repositories/comunicados_repository.dart';
import '../repositories/exames_repository.dart';   // ExamesRepository
import '../services/dev_api.dart';
import '../services/api_router.dart';
import '../config/app_config.dart';      // <-- novo
import '../api/cards_page_scraper.dart'; // <-- novo

import '../ui/app_shell.dart';           // AppScaffold
import '../ui/components/exames_inline_status.dart';
import '../ui/components/quick_actions.dart';
import '../ui/components/quick_action_items.dart';
import '../ui/components/section_card.dart';
import '../ui/components/section_list.dart';
import '../ui/components/loading_placeholder.dart';
import '../ui/components/locked_notice.dart';
import '../ui/components/resumo_row.dart';
import '../ui/components/welcome_card.dart';
import '../ui/components/minha_situacao_card.dart';
import 'login_screen.dart';
import 'home_servicos.dart';
import 'profile_screen.dart';
import '../ui/components/requerimentos_card.dart';
import '../ui/components/comunicados_card.dart';

import '../models/exame.dart';           // ExameResumo
import '../flows/visitor_consent.dart';
import '../root_nav_shell.dart';

// Controller/State
import '../controllers/home_controller.dart';
import '../controllers/home_state_controller.dart'; // HomeState

// Comunicados via HTML cards
import '../services/comunicados_service.dart';
import '../ui/components/comunicado_detail_sheet.dart';

// Fluxo da Carteirinha direto na Home
import '../screens/carteirinha_flow.dart';

// Sheet com as três autorizações (navega internamente)
import 'authorizations_picker_sheet.dart' show showAuthorizationsPickerSheet;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  // Tabs da RootNavShell
  static const int _TAB_HOME     = 0;
  static const int _TAB_SERVICOS = 1;
  static const int _TAB_PERFIL   = 2;

  // Controladores/Serviços
  late final HomeController _ctrl;
  late final ComunicadosService _comSvc;
  late final ExamesRepository _exRepo;
  late final DevApi _api;

  bool _ctrlReady = false;
  bool _didPromptConsent = false;

  // Exames (estado local da Home)
  List<ExameResumo> _examesHome = const [];
  bool _exLoading = false;
  int? _exLoadedForMatricula; // evita recarregar sem necessidade

  // Sexo do titular (puxado via carteirinha)
  String? _sexoTxtHome;
  bool _sexoLoading = false;
  int? _sexoLoadedForMatricula; // para não ficar batendo sempre

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ctrlReady) return;

    _api = ApiRouter.client();

    final depsRepo = DependentsRepository(_api);

    // Usa a base do AppConfig (main / main_local) para resolver a URL dos cards
    final cfg = AppConfig.of(context);
    final baseApiUrl = cfg.params.baseApiUrl;
    final cardsScraper = CardsPageScraper.forBaseApi(baseApiUrl);
    final comRepo = ComunicadosRepository(cardsScraper);

    _exRepo = ExamesRepository(_api);

    // Serviço de comunicados com cache em memória (por cima do scraper HTML)
    _comSvc = ComunicadosService(repository: comRepo);

    // Controller principal da Home
    _ctrl = HomeController(
      session: SessionStore(),
      depsRepo: depsRepo,
      comRepo: comRepo,
    )..load();

    _ctrlReady = true;
  }

  // ===== Exames (Home) =======================================================

  Future<void> _loadExamesHome(int idMatricula) async {
    if (_exLoading) return;
    _exLoading = true;
    try {
      final list = await _exRepo.listarUltimosAP(
        idMatricula: idMatricula,
        limit: 3,
      );
      if (!mounted) return;
      setState(() {
        _examesHome = list;
        _exLoadedForMatricula = idMatricula;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _examesHome = const [];
      });
    } finally {
      if (mounted) {
        setState(() => _exLoading = false);
      } else {
        _exLoading = false;
      }
    }
  }

  void _ensureExamesFor(HomeState s) {
    if (!s.isLoggedIn) {
      if (_examesHome.isNotEmpty) {
        setState(() {
          _examesHome = const [];
          _exLoadedForMatricula = null;
        });
      }
      return;
    }
    final id = s.profile?.id;
    if (id == null) return;
    if (_exLoadedForMatricula != id && !_exLoading) {
      _loadExamesHome(id);
    }
  }

  // ===== Sexo (via carteirinha) =============================================

  Future<void> _loadSexoForMatricula(int idMatricula) async {
    if (_sexoLoading) return;
    _sexoLoading = true;
    try {
      final res = await _api.postAction<dynamic>(
        'carteirinha',
        data: {'idmatricula': idMatricula},
      );
      final root = (res.data as Map).cast<String, dynamic>();
      if (root['ok'] == true && root['data'] is Map) {
        final data = (root['data'] as Map).cast<String, dynamic>();
        final titularRaw = data['titular'];
        String? sexoTxt;
        if (titularRaw is Map) {
          final tit = titularRaw.cast<String, dynamic>();
          sexoTxt = (tit['sexo_txt'] ??
              tit['sexoTxt'] ??
              tit['sexo'])
              ?.toString();
        }

        if (!mounted) return;
        setState(() {
          _sexoTxtHome = sexoTxt;
          _sexoLoadedForMatricula = idMatricula;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sexoTxtHome = null;
        _sexoLoadedForMatricula = idMatricula; // evita bater sem parar em caso de erro
      });
    } finally {
      _sexoLoading = false;
    }
  }

  void _ensureSexoFor(HomeState s) {
    if (!s.isLoggedIn) {
      if (_sexoTxtHome != null || _sexoLoadedForMatricula != null) {
        setState(() {
          _sexoTxtHome = null;
          _sexoLoadedForMatricula = null;
        });
      }
      return;
    }

    final id = s.profile?.id;
    if (id == null || id <= 0) return;

    if (_sexoLoadedForMatricula == id || _sexoLoading) return;

    _loadSexoForMatricula(id);
  }

  // ===== Comunicados (detalhe) ==============================================

  void _openComunicado(ComunicadoResumo it) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ComunicadoDetailSheet.fromResumo(resumo: it),
    );
  }

  // ===== Navegação mantendo hotbar ===========================================

  bool _switchTab(int index) {
    final scope = RootNavShell.maybeOf(context);
    if (scope != null) {
      scope.setTab(index);
      return true;
    }
    return false;
  }

  // ===== Quick Actions (via presets) ========================================

  Widget _quickActionsFor(HomeState s) {
    final items = QuickActionItems.homeDefault(
      context: context,
      idMatricula: s.profile?.id,
    );

    return QuickActions(
      title: 'Ações rápidas',
      items: items,
      isLoggedIn: s.isLoggedIn,
      onRequireLogin: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      },
    );
  }

  // ===== Build ===============================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_ctrlReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final s = _ctrl.state;

        // Busca exames quando logar/trocar usuário
        _ensureExamesFor(s);

        // Busca sexo do titular (via carteirinha) quando logar/trocar usuário
        _ensureSexoFor(s);

        // Consentimento de visitante
        if (!s.loading && !s.isLoggedIn && !_didPromptConsent) {
          _didPromptConsent = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await ensureVisitorConsent(context);
          });
        }

        return AppScaffold(
          title: 'Início',
          body: RefreshIndicator(
            onRefresh: () async {
              await _ctrl.load();
              final id = _ctrl.state.profile?.id;
              if (id != null) {
                await _loadExamesHome(id);
                await _loadSexoForMatricula(id);
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth >= 640 ? 24.0 : 16.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
                      children: [
                        // ===== Cabeçalho
                        WelcomeCard(
                          isLoggedIn: s.isLoggedIn,
                          name: s.isLoggedIn ? s.profile?.nome : null,
                          cpf: s.isLoggedIn
                              ? (s.profile != null && (s.profile!.cpf).isNotEmpty
                              ? fmtCpf(s.profile!.cpf)
                              : null)
                              : (s.cpf == null || s.cpf!.isEmpty
                              ? null
                              : fmtCpf(s.cpf!)),
                          sexoTxt: s.isLoggedIn ? _sexoTxtHome : null,
                          onLogin: s.isLoggedIn
                              ? () {}
                              : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ===== Comunicados (consumindo as views JSON do Yii)
                        ComunicadosCard(
                          isLoading: s.loading,
                          items: s.comunicados,
                          take: 3,
                          skeletonHeight: 100,
                          onTapItem: (c) => _openComunicado(c),
                        ),

                        const SizedBox(height: 16),

                        // ===== Ações rápidas
                        _quickActionsFor(s),

                        const SizedBox(height: 16),

                        // ===== Requerimentos + Exames (no mesmo card)
                        RequerimentosEmAndamentoCard(
                          isLoading: s.loading,
                          items: s.reqs,
                          take: 3,
                          skeletonHeight: 100,
                          onTapItem: (req) {
                            // trate o toque do requerimento se necessário
                          },
                          extraInner: const ExamesInlineStatusList(take: 3),
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
