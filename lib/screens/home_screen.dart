import 'package:flutter/material.dart';

import '../core/formatters.dart';        // fmtData, fmtCpf
import '../core/models.dart';            // RequerimentoResumo, ComunicadoResumo
import '../data/session_store.dart';     // SessionStore
import '../repositories/dependents_repository.dart';
import '../repositories/comunicados_repository.dart';
import '../services/dev_api.dart';
import '../config/app_config.dart';

import '../ui/app_shell.dart';           // AppScaffold
import '../ui/components/quick_actions.dart'; // << novo flexível
import '../ui/components/section_card.dart';
import '../ui/components/section_list.dart';
import '../ui/components/loading_placeholder.dart';
import '../ui/components/locked_notice.dart';
import '../ui/components/resumo_row.dart';
import '../ui/components/welcome_card.dart';
import '../ui/components/minha_situacao_card.dart'; // card "Minha Situação"
import 'login_screen.dart';
import 'home_servicos.dart';
import 'profile_screen.dart';
import '../ui/components/requerimentos_card.dart';
import '../ui/components/comunicados_card.dart';


import '../flows/visitor_consent.dart';

// Navegação via Shell (para manter hotbar)
import '../root_nav_shell.dart';

// ===== Controller/State =====
import '../controllers/home_controller.dart';
import '../controllers/home_state_controller.dart'; // reexporta HomeState

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  // Índices de abas na RootNavShell
  static const int _TAB_HOME     = 0;
  static const int _TAB_SERVICOS = 1;
  static const int _TAB_PERFIL   = 2;

  late HomeController _ctrl;
  bool _ctrlReady = false;

  // Para exibir o consent uma única vez
  bool _didPromptConsent = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ctrlReady) {
      final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
          ?? const String.fromEnvironment(
            'API_BASE',
            defaultValue: 'https://assistweb.ipasemnh.com.br',
          );

      final depsRepo = DependentsRepository(DevApi(baseUrl));
      final comRepo  = const ComunicadosRepository();

      _ctrl = HomeController(
        session: SessionStore(),
        depsRepo: depsRepo,
        comRepo: comRepo, // comunicados via repositório
      )..load();

      _ctrlReady = true;
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
    // Fallback (evite no dia a dia)
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomeServicos()));
  }

  void _goToPerfil() {
    if (_switchTab(_TAB_PERFIL)) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  // ====== NOVA ROTINA: monta as ações por tipo de login ======
  Widget _quickActionsFor(HomeState s) {
    final isLogged = s.isLoggedIn;

    final items = <QuickActionItem>[
      // Disponível para todos, mas exige login para funcionar
      QuickActionItem(
        id: 'carteirinha',
        label: 'Carteirinha',
        icon: Icons.badge_outlined,
        onTap: _goToServicos,
        audience: QaAudience.all,
        requiresLogin: true,
      ),
      // Disponível para todos, sem exigir login (pode abrir serviços/infos públicas)
      QuickActionItem(
        id: 'assistencia',
        label: 'Serviços',
        icon: Icons.local_hospital_outlined,
        onTap: _goToServicos,
        audience: QaAudience.all,
        requiresLogin: false,
      ),
      // Exige login
      QuickActionItem(
        id: 'autorizacoes',
        label: 'Autoriz\u00E7\u00F5es', // evita problemas de encoding
        icon: Icons.assignment_turned_in_outlined,
        onTap: _goToServicos,
        audience: QaAudience.all,
        requiresLogin: true,
      ),

      // Exemplo de item só para visitante (se quiser estimular login)
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

      // Exemplo de item só para logado (se quiser atalho ao Perfil)
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
        // Comportamento padrão ao tocar em item bloqueado quando visitante:
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
      // proteção rápida (primeiro build antes do didChangeDependencies)
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final s = _ctrl.state;

        // dispara o consent para visitante (uma única vez)
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
            onRefresh: _ctrl.load,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth >= 640 ? 24.0 : 16.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
                      children: [
                        // ===== Cabeçalho (sempre mostra; o card decide o layout)
                        WelcomeCard(
                          isLoggedIn: s.isLoggedIn,
                          name: s.isLoggedIn ? s.profile?.nome : null,
                          cpf: s.isLoggedIn
                              ? (s.profile != null && (s.profile!.cpf).isNotEmpty
                              ? fmtCpf(s.profile!.cpf)
                              : null)
                              : (s.cpf == null || s.cpf!.isEmpty ? null : fmtCpf(s.cpf!)),
                          // onLogin é required; quando logado, passo no-op.
                          onLogin: s.isLoggedIn
                              ? () {}
                              : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ===== Ações rápidas (controladas por rotina)
                        _quickActionsFor(s),

                        const SizedBox(height: 16),

                        // ===== Minha Situação
                        MinhaSituacaoCard(
                          isLoading: s.loading,
                          isLoggedIn: s.isLoggedIn,
                          situacao: s.isLoggedIn ? 'Ativo' : null, // padrão quando logado
                          plano: s.isLoggedIn ? '—' : null,        // placeholder até SP
                          dependentes: dependentesCount,
                        ),

                        const SizedBox(height: 12),

                        // ===== Requerimentos em andamento
                        RequerimentosEmAndamentoCard(
                          isLoading: s.loading,
                          items: s.reqs,
                          take: 3,
                          skeletonHeight: 100,
                          // onTapItem: (req) { ... abrir detalhe se quiser ... },
                        ),

                        const SizedBox(height: 12),

                        // ===== Comunicados
                        ComunicadosCard(
                          isLoading: s.loading,
                          items: s.comunicados,
                          take: 3,
                          skeletonHeight: 100,
                          // onTapItem: (c) { ... abrir detalhe se quiser ... },
                        ),
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
