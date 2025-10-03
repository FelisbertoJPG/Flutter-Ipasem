import 'package:flutter/material.dart';

import '../core/formatters.dart';        // fmtData, fmtCpf
import '../core/models.dart';            // RequerimentoResumo, ComunicadoResumo
import '../data/session_store.dart';     // SessionStore
import '../services/session.dart';       // Session.getProfile()
import '../models/profile.dart';
import '../models/dependent.dart';
import '../repositories/dependents_repository.dart';
import '../services/dev_api.dart';
import '../config/app_config.dart';

import '../theme/colors.dart';
import '../ui/app_shell.dart';           // AppScaffold
import '../ui/components/header_card.dart';
import '../ui/components/quick_actions.dart';
import '../ui/components/section_card.dart';
import '../ui/components/section_list.dart';
import '../ui/components/loading_placeholder.dart';
import '../ui/components/locked_notice.dart';
import '../ui/components/resumo_row.dart';
import '../ui/components/welcome_card.dart';
import 'login_screen.dart';
import 'home_servicos.dart';
import 'profile_screen.dart';

import '../flows/visitor_consent.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final _session = SessionStore();

  bool _loading = true;
  bool _isLoggedIn = false;
  String? _cpf;

  // novos: perfil + dependentes reais
  Profile? _profile;
  List<Dependent> _deps = const [];

  // repos para chamadas (dependentes)
  late DependentsRepository _depsRepo;
  bool _depsReady = false;

  List<RequerimentoResumo> _reqEmAndamento = const [];
  List<ComunicadoResumo> _comunicados = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsReady) {
      final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
          ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');
      _depsRepo = DependentsRepository(DevApi(baseUrl));
      _depsReady = true;
    }
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);

    final logged = await _session.getIsLoggedIn();
    final cpf    = await _session.getSavedCpf();

    // Stubs — (mantidos) para cards de requerimentos/comunicados
    final req = <RequerimentoResumo>[];
    final avisos = <ComunicadoResumo>[
      ComunicadoResumo(
        titulo: 'Manutenção programada',
        descricao: 'Sistema de autorizações ficará indisponível no domingo, 02:00–04:00.',
        data: DateTime.now(),
      ),
      ComunicadoResumo(
        titulo: 'Novo canal de atendimento',
        descricao: 'WhatsApp do setor de benefícios atualizado.',
        data: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    Profile? prof;
    List<Dependent> deps = const [];

    if (logged) {
      // carrega perfil salvo pela tela de login
      prof = await Session.getProfile();
      // se tiver perfil, busca dependentes pela matrícula (id)
      if (prof != null && _depsReady) {
        try {
          deps = await _depsRepo.listByMatricula(prof.id);
        } catch (_) {
          // silencioso por enquanto; podemos mostrar um toast depois
          deps = const [];
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoggedIn = logged;
      _cpf = cpf;
      _profile = prof;
      _deps = deps;
      _reqEmAndamento = req;
      _comunicados = avisos;
      _loading = false;
    });

    // Se visitante e ainda não aceitou, mostra o diálogo após o primeiro frame
    if (!_isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await ensureVisitorConsent(context);
      });
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

    final dependentesCount = _isLoggedIn ? _deps.length : 0;

    return AppScaffold(
      title: 'Início',
      body: RefreshIndicator(
        onRefresh: _bootstrap,
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
                      isLoggedIn: _isLoggedIn,
                      name: _isLoggedIn ? _profile?.nome : null,
                      cpf: _isLoggedIn
                          ? (_profile != null && _profile!.cpf.isNotEmpty ? fmtCpf(_profile!.cpf) : null)
                          : (_cpf == null || _cpf!.isEmpty ? null : fmtCpf(_cpf!)),
                      // onLogin é required no componente; quando logado, passo no-op.
                      onLogin: _isLoggedIn
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

                    // ===== Minha Situação
                    SectionCard(
                      title: 'Minha Situação',
                      child: _loading
                          ? const LoadingPlaceholder(height: 72)
                          : (_isLoggedIn
                          ? _MinhaSituacaoResumo(
                        vinculo: '—',                // ainda não temos SP pra isso
                        plano: '—',                  // idem
                        dependentes: dependentesCount,
                      )
                          : const LockedNotice(
                        message:
                        'Faça login para visualizar seus dados de vínculo, plano e dependentes.',
                      )),
                    ),

                    const SizedBox(height: 12),

                    // ===== Requerimentos em andamento (stub mantido)
                    SectionList<RequerimentoResumo>(
                      title: 'Requerimentos em andamento',
                      isLoading: _loading,
                      items: _reqEmAndamento,
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

                    // ===== Comunicados (stub mantido)
                    SectionList<ComunicadoResumo>(
                      title: 'Comunicados',
                      isLoading: _loading,
                      items: _comunicados,
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
                      emptyTitle: 'Sem comunicados no momento',
                      emptySubtitle:
                      'Novos avisos oficiais do IPASEM aparecerão aqui.',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ====== Pequeno widget específico, mas fino o suficiente para ficar aqui ======

class _MinhaSituacaoResumo extends StatelessWidget {
  const _MinhaSituacaoResumo({
    required this.vinculo,
    required this.plano,
    required this.dependentes,
  });

  final String vinculo;
  final String plano;
  final int dependentes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ResumoRow(icon: Icons.badge_outlined, label: 'Vínculo', value: vinculo),
        ResumoRow(
          icon: Icons.medical_services_outlined,
          label: 'Plano de saúde',
          value: plano,
        ),
        ResumoRow(
          icon: Icons.group_outlined,
          label: 'Dependentes',
          value: '$dependentes',
        ),
      ],
    );
  }
}
