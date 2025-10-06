import 'package:flutter/material.dart';

import '../core/formatters.dart';        // fmtData, fmtCpf
import '../core/models.dart';            // RequerimentoResumo, ComunicadoResumo
import '../data/session_store.dart';     // SessionStore
import '../repositories/dependents_repository.dart';
import '../repositories/comunicados_repository.dart';
import '../services/dev_api.dart';
import '../config/app_config.dart';

import '../ui/app_shell.dart';           // AppScaffold
import '../ui/components/quick_actions.dart';
import '../ui/components/section_card.dart';
import '../ui/components/section_list.dart';
import '../ui/components/loading_placeholder.dart';
import '../ui/components/locked_notice.dart';
import '../ui/components/resumo_row.dart';
import '../ui/components/welcome_card.dart';
import '../ui/components/minha_situacao_card.dart'; // <<< novo card
import 'login_screen.dart';
import 'home_servicos.dart';
import 'profile_screen.dart';

import '../flows/visitor_consent.dart';

// ===== CORRIGIDO =====
import '../controllers/home_controller.dart';
import '../controllers/home_state_controller.dart'; // reexporta HomeState (evita importar home_state.dart direto)

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  // Controller
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
        comRepo: comRepo,                      // comunicados via repositório
      )..load();

      _ctrlReady = true;
    }
  }

  // ---- Navegação ----
  void _goToServicos() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HomeServicos()),
    );
  }

  void _goToPerfil() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
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

                        // ===== Ações rápidas (leva para Serviços)
                        QuickActions(
                          onCarteirinha: _goToServicos,
                          onAssistenciaSaude: _goToServicos,
                          onAutorizacoes: _goToServicos,
                        ),

                        const SizedBox(height: 16),

                        // ===== Minha Situação (agora componente dedicado)
                        MinhaSituacaoCard(
                          isLoading: s.loading,
                          isLoggedIn: s.isLoggedIn,
                          situacao: s.isLoggedIn ? 'Ativo' : null, // padrão quando logado
                          plano: s.isLoggedIn ? '—' : null,        // placeholder até SP
                          dependentes: dependentesCount,
                        ),

                        const SizedBox(height: 12),

                        // ===== Requerimentos em andamento (stub mantido)
                        SectionList<RequerimentoResumo>(
                          title: 'Requerimentos em andamento',
                          isLoading: s.loading,
                          items: s.reqs,
                          take: 3,
                          skeletonHeight: 100,
                          itemBuilder: (e) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.description_outlined),
                            title: Text(
                              e.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Status: ${e.status} • Atualizado: ${fmtData(e.atualizadoEm)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                          emptyIcon: Icons.assignment_outlined,
                          emptyTitle: 'Nenhum requerimento em andamento',
                          emptySubtitle:
                          'Quando houverem movimentações, elas aparecerão aqui.',
                        ),

                        const SizedBox(height: 12),

                        // ===== Comunicados (vêm do repositório via controller.state)
                        SectionList<ComunicadoResumo>(
                          title: 'Comunicados',
                          isLoading: s.loading,
                          items: s.comunicados,
                          take: 3,
                          skeletonHeight: 100,
                          itemBuilder: (c) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.campaign_outlined),
                            title: Text(
                              c.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${fmtData(c.data)} • ${c.descricao}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          emptyIcon: Icons.campaign_outlined,
                          emptyTitle: 'Sem comunicados Publicados',
                          emptySubtitle:
                          'Novos avisos oficiais aparecerão aqui.',
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
