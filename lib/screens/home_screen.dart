import 'package:flutter/material.dart';

import '../core/formatters.dart';        // fmtData, fmtCpf
import '../core/models.dart';            // RequerimentoResumo, ComunicadoResumo
import '../data/session_store.dart';     // SessionStore
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

  List<RequerimentoResumo> _reqEmAndamento = const [];
  List<ComunicadoResumo> _comunicados = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);

    final logged = await _session.getIsLoggedIn();
    final cpf = await _session.getSavedCpf();

    // Stubs — troque por chamadas HTTP
    final req = <RequerimentoResumo>[];
    final avisos = <ComunicadoResumo>[
      ComunicadoResumo(
        titulo: 'Manutenção programada',
        descricao:
        'Sistema de autorizações ficará indisponível no domingo, 02:00–04:00.',
        data: DateTime.now(),
      ),
      ComunicadoResumo(
        titulo: 'Novo canal de atendimento',
        descricao: 'WhatsApp do setor de benefícios atualizado.',
        data: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    setState(() {
      _isLoggedIn = logged;
      _cpf = cpf;
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
                  padding:
                  EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
                  children: [


                    // ===== Cabeçalho Visitante/Logado
                    if (!_isLoggedIn)
                      WelcomeCard(
                        isLoggedIn: _isLoggedIn,
                        cpf: _cpf == null || _cpf!.isEmpty ? null : fmtCpf(_cpf!),
                        onLogin: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                      ),
                    const SizedBox(height: 16),



                    // ===== Ações rápidas (leva para Serviços)
                    QuickActions(
                      onCarteirinha: () => _goToServicos,
                      onAssistenciaSaude: () => _goToServicos,
                      onAutorizacoes: () => _goToServicos,
                    ),
                    const SizedBox(height: 16),

                    // ===== Minha Situação
                    SectionCard(
                      title: 'Minha Situação',
                      child: _loading
                          ? const LoadingPlaceholder(height: 72)
                          : (_isLoggedIn
                          ? const _MinhaSituacaoResumo(
                        vinculo: 'Ativo',
                        plano: 'Plano Saúde IPASEM',
                        dependentes: 2,
                      )
                          : const LockedNotice(
                        message:
                        'Faça login para visualizar seus dados de vínculo, plano e dependentes.',
                      )),
                    ),
                    const SizedBox(height: 12),

                    // ===== Requerimentos em andamento
                    SectionList<RequerimentoResumo>(
                      title: 'Requerimentos em andamento',
                      isLoading: _loading,
                      items: _reqEmAndamento,
                      take: 3,
                      skeletonHeight: 100,
                      itemBuilder: (e) => ListTile(
                        dense: true,
                        leading:
                        const Icon(Icons.description_outlined),
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

                    // ===== Comunicados
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
            value: plano),
        ResumoRow(
            icon: Icons.group_outlined,
            label: 'Dependentes',
            value: '$dependentes'),
      ],
    );
  }
}
