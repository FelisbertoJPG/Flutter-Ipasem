// lib/frontend/screens/home_screen.dart
import 'package:flutter/material.dart';

import '../../../backend/controller/home_controller.dart';
import '../../../backend/controller/home_state.dart';
import '../../../backend/config/formatters.dart';
import '../../../backend/models/models.dart'; // ComunicadoResumo, etc.

import '../../../common/config/app_config.dart';
import '../../../common/config/api_router.dart';
import '../../../common/config/dev_api.dart';

import '../../../common/data/session_store.dart';
import '../../../common/models/exame.dart';
import '../../../common/repositories/comunicados_repository.dart';
import '../../../common/repositories/dependents_repository.dart';
import '../../../common/repositories/exames_repository.dart';

import '../../../common/services/comunicados_service/comunicados_service.dart';

import '../components/comunicados_comp/comunicado_detail_sheet.dart';
import '../components/comunicados_comp/comunicados_card.dart';
import '../components/exames_comp/exames_inline_status.dart';
import '../components/quick_actions.dart';
import '../components/cards/requerimentos_card.dart';
import '../components/cards/welcome_card.dart';
import '../components/acoes_rapidas_comp/quick_action_items.dart';

import '../layouts/root_nav_shell.dart';
import '../layouts/menu_shell.dart'; // se o AppScaffold estiver aqui

import '../../visitante/visitor_consent.dart';
import 'authorizations_picker_sheet.dart' show showAuthorizationsPickerSheet;
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  // Tabs da RootNavShell (se precisar navegar mantendo o bottom bar)
  static const int _TAB_HOME = 0;
  static const int _TAB_SERVICOS = 1;
  static const int _TAB_PERFIL = 2;

  // Controladores/Serviços principais
  late final HomeController _ctrl;
  late final ExamesRepository _exRepo;
  late final DevApi _api;

  bool _ctrlReady = false;
  bool _didPromptConsent = false;

  // ===== Exames (estado local da Home) ======================================
  List<ExameResumo> _examesHome = const [];
  bool _exLoading = false;
  int? _exLoadedForMatricula; // evita recarregar sem necessidade

  // ===== Sexo do titular (via carteirinha) ==================================
  String? _sexoTxtHome;
  bool _sexoLoading = false;
  int? _sexoLoadedForMatricula;

  // ===== Comunicados (Home) – via ComunicadosService ========================
  late final ComunicadosService _comSvc;
  bool _comLoading = false;
  List<ComunicadoResumo> _comHome = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ctrlReady) return;

    _api = ApiRouter.client();

    final depsRepo = DependentsRepository(_api);
    _exRepo = ExamesRepository(_api);

    // baseApiUrl vem do AppConfig (main / main_local)
    final baseApiUrl = AppConfig.of(context).params.baseApiUrl;

    // Repo de comunicados usando a URL correta de /comunicacao-app/cards
    final comRepo = ComunicadosRepository.fromBaseApi(baseApiUrl);

    // Serviço de alto nível (cache em memória, filtros, etc.)
    _comSvc = ComunicadosService(repository: comRepo);

    // Controller principal da Home (continua cuidando de sessão, reqs, etc.)
    _ctrl = HomeController(
      session: SessionStore(),
      depsRepo: depsRepo,
      comRepo: comRepo,
    )..load();

    _ctrlReady = true;

    // Carrega comunicados para o card da Home
    _loadComunicadosHome();
  }

  // ==========================================================================
  // Exames (Home)
  // ==========================================================================

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

  // ==========================================================================
  // Sexo (via carteirinha)
  // ==========================================================================

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
        _sexoLoadedForMatricula =
            idMatricula; // evita bater sem parar em caso de erro
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

  // ==========================================================================
  // Comunicados (Home) – lista + detalhe
  // ==========================================================================

  Future<void> _loadComunicadosHome({bool forceRefresh = false}) async {
    setState(() => _comLoading = true);

    try {
      final list = await _comSvc.listar(
        limit: 3,          // quantidade exibida no card
        categoria: 'home', // ou null / outra categoria se quiser
        q: null,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _comHome = list;
        _comLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comHome = const [];
        _comLoading = false;
      });
    }
  }

  void _openComunicado(ComunicadoResumo it) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ComunicadoDetailSheet.fromResumo(resumo: it),
    );
  }

  // ==========================================================================
  // Navegação mantendo hotbar
  // ==========================================================================

  bool _switchTab(int index) {
    final scope = RootNavShell.maybeOf(context);
    if (scope != null) {
      scope.setTab(index);
      return true;
    }
    return false;
  }

  // ==========================================================================
  // Quick Actions (via presets)
  // ==========================================================================

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

  // ==========================================================================
  // Build
  // ==========================================================================

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
              await _loadComunicadosHome(forceRefresh: true);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal =
                constraints.maxWidth >= 640 ? 24.0 : 16.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        16,
                        horizontal,
                        24,
                      ),
                      children: [
                        // ===== Cabeçalho
                        WelcomeCard(
                          isLoggedIn: s.isLoggedIn,
                          name: s.isLoggedIn ? s.profile?.nome : null,
                          cpf: s.isLoggedIn
                              ? (s.profile != null &&
                              (s.profile!.cpf).isNotEmpty
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
                              builder: (_) =>
                              const LoginScreen(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ===== Comunicados (card da Home)
                        ComunicadosCard(
                          isLoading: _comLoading,
                          items: _comHome,
                          take: 3,
                          skeletonHeight: 100,
                          onTapItem: _openComunicado,
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
                          extraInner:
                          const ExamesInlineStatusList(take: 3),
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
