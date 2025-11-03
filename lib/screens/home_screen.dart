// lib/screens/home_screen.dart
import 'package:flutter/material.dart';

import '../core/formatters.dart';        // fmtData, fmtCpf
import '../core/models.dart';            // RequerimentoResumo, ComunicadoResumo
import '../data/session_store.dart';     // SessionStore
import '../repositories/dependents_repository.dart';
import '../repositories/comunicados_repository.dart';
import '../repositories/exames_repository.dart';   // <-- NOVO
import '../services/dev_api.dart';
import '../services/api_router.dart';

import '../ui/app_shell.dart';           // AppScaffold
import '../ui/components/exames_inline_status.dart';
import '../ui/components/quick_actions.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  static const int _TAB_HOME     = 0;
  static const int _TAB_SERVICOS = 1;
  static const int _TAB_PERFIL   = 2;

  late HomeController _ctrl;
  bool _ctrlReady = false;

  bool _didPromptConsent = false;

  // NOVO: repositório de exames e estado local dos exames da Home
  late ExamesRepository _exRepo;
  List<ExameResumo> _examesHome = const [];
  bool _exLoading = false;
  int? _exLoadedForMatricula; // para não refazer desnecessariamente

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ctrlReady) {
      // Fonte única de verdade para base/gateway
      final DevApi api = ApiRouter.client();

      final depsRepo = DependentsRepository(api);
      final comRepo  = const ComunicadosRepository();
      _exRepo        = ExamesRepository(api); // NOVO

      _ctrl = HomeController(
        session: SessionStore(),
        depsRepo: depsRepo,
        comRepo: comRepo,
      )..load();

      _ctrlReady = true;
    }
  }

  Future<void> _loadExamesHome(int idMatricula) async {
    if (_exLoading) return;
    setState(() => _exLoading = true);
    try {
      final list = await _exRepo.listarUltimosAP(idMatricula: idMatricula, limit: 3);
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
      if (mounted) setState(() => _exLoading = false);
    }
  }

  // Chama quando o state do controller muda
  void _ensureExamesFor(HomeState s) {
    if (!s.isLoggedIn) {
      if (_examesHome.isNotEmpty) setState(() => _examesHome = const []);
      _exLoadedForMatricula = null;
      return;
    }
    final id = s.profile?.id;
    if (id == null) return;
    if (_exLoadedForMatricula != id && !_exLoading) {
      _loadExamesHome(id);
    }
  }

  // ====== Navegação mantendo hotbar ======
  bool _switchTab(int index) {
    final scope = RootNavShell.maybeOf(context);
    if (scope != null) {
      scope.setTab(index);
      return true;
    }
    return false;
  }

  void _goToServicos() {
    if (_switchTab(_TAB_SERVICOS)) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomeServicos()));
  }

  void _goToPerfil() {
    if (_switchTab(_TAB_PERFIL)) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  Widget _quickActionsFor(HomeState s) {
    final isLogged = s.isLoggedIn;

    final items = <QuickActionItem>[
      QuickActionItem(
        id: 'carteirinha',
        label: 'Carteirinha',
        icon: Icons.badge_outlined,
        onTap: _goToServicos,
        audience: QaAudience.all,
        requiresLogin: true,
      ),
      QuickActionItem(
        id: 'assistencia',
        label: 'Serviços',
        icon: Icons.local_hospital_outlined,
        onTap: _goToServicos,
        audience: QaAudience.all,
        requiresLogin: false,
      ),
      QuickActionItem(
        id: 'autorizacoes',
        label: 'Autoriz\u00E7\u00F5es',
        icon: Icons.assignment_turned_in_outlined,
        onTap: _goToServicos,
        audience: QaAudience.all,
        requiresLogin: true,
      ),
      if (!isLogged)
        QuickActionItem(
          id: 'login',
          label: 'Fazer login',
          icon: Icons.login_outlined,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          audience: QaAudience.visitor,
          requiresLogin: false,
        ),
      if (isLogged)
        QuickActionItem(
          id: 'perfil',
          label: 'Meu Perfil',
          icon: Icons.person_outline,
          onTap: _goToPerfil,
          audience: QaAudience.loggedIn,
          requiresLogin: false,
        ),
    ];

    return QuickActions(
      title: 'Ações rápidas',
      items: items,
      isLoggedIn: isLogged,
      onRequireLogin: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      },
    );
  }

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

        // Garante que buscamos os exames quando logar / trocar usuário
        _ensureExamesFor(s);

        if (!s.loading && !s.isLoggedIn && !_didPromptConsent) {
          _didPromptConsent = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await ensureVisitorConsent(context);
          });
        }

        final dependentesCount = s.isLoggedIn ? s.dependents.length : 0;

        return AppScaffold(
          title: 'Início',
          body: RefreshIndicator(
            onRefresh: () async {
              await _ctrl.load();
              final id = _ctrl.state.profile?.id;
              if (id != null) await _loadExamesHome(id);
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
                              : (s.cpf == null || s.cpf!.isEmpty ? null : fmtCpf(s.cpf!)),
                          onLogin: s.isLoggedIn
                              ? () {}
                              : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ===== Comunicados
                        ComunicadosCard(
                          isLoading: s.loading,
                          items: s.comunicados,
                          take: 3,
                          skeletonHeight: 100,
                          onTapItem: (c) {},
                        ),

                        const SizedBox(height: 16),

                        // ===== Ações rápidas
                        _quickActionsFor(s),

                        const SizedBox(height: 16),

                        // ===== Minha Situação
                        MinhaSituacaoCard(
                          isLoading: s.loading,
                          isLoggedIn: s.isLoggedIn,
                          situacao: s.isLoggedIn ? 'Ativo' : null,
                          //plano: s.isLoggedIn ? '—' : null,
                          dependentes: dependentesCount,
                        ),

                        const SizedBox(height: 12),

                        // ===== Requerimentos + Exames (no mesmo card)
                        RequerimentosEmAndamentoCard(
                          isLoading: s.loading,        // o widget de exames cuida do loading dele
                          items: s.reqs,
                          take: 3,
                          skeletonHeight: 100,
                          onTapItem: (req) {
                            // se quiser, trate o toque do "requerimento" aqui
                            // (req é RequerimentoResumo, não tem 'numero')
                          },
                          extraInner: const ExamesInlineStatusList(take: 3), // << AQUI, fora do onTapItem
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
