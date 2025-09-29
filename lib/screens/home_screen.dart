import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/formatters.dart';
import '../core/models.dart';
import '../data/session_store.dart';
import '../theme/colors.dart';
import '../ui/app_shell.dart';
import '../ui/components/section_card.dart';
import '../ui/components/status_chip.dart';
import '../ui/components/action_tile.dart';
import '../ui/components/locked_notice.dart';
import '../ui/components/loading_placeholder.dart';
import '../ui/components/resumo_row.dart';

import 'login_screen.dart';
import 'home_servicos.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final _session = SessionStore();

  bool _loading = true;
  bool _isLoggedIn = false; // Visitante por padrão
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

    // Sessão (enquanto não houver login real, permanece visitante)
    final logged = await _session.getIsLoggedIn();
    final cpf = await _session.getSavedCpf();

    // Stubs iniciais (em produção, troque por chamadas HTTP)
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

    setState(() {
      _isLoggedIn = logged;
      _cpf = cpf;
      _reqEmAndamento = req;
      _comunicados = avisos;
      _loading = false;
    });
  }

  // ---- Navegação ----
  void _goToServicos(BuildContext ctx) {
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const HomeServicos()));
  }

  void _goToPerfil(BuildContext ctx) {
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  Future<void> _logout(BuildContext ctx) async {
    await _session.clearSession();
    if (!mounted) return;
    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
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
                  padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
                  children: [
                    // ===== Cabeçalho Visitante/Logado
                    _HeaderCard(
                      isLoggedIn: _isLoggedIn,
                      cpf: _cpf,
                      onLogin: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      onPerfil: () => _goToPerfil(context),
                    ),
                    const SizedBox(height: 16),

                    // ===== Ações rápidas
                    _QuickActions(
                      onCarteirinha: () => _goToServicos(context),
                      onAssistenciaSaude: () => _goToServicos(context),
                      onAutorizacoes: () => _goToServicos(context),
                    ),
                    const SizedBox(height: 16),

                    // ===== Minha Situação
                    SectionCard(
                      title: 'Minha Situação',
                      child: _loading
                          ? const LoadingPlaceholder(height: 72)
                          : _isLoggedIn
                          ? const _MinhaSituacaoResumo(
                        vinculo: 'Ativo',
                        plano: 'Plano Saúde IPASEM',
                        dependentes: 2,
                      )
                          : const LockedNotice(
                        message: 'Faça login para visualizar seus dados de vínculo, plano e dependentes.',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ===== Em andamento (Requerimentos)
                    SectionCard(
                      title: 'Requerimentos em andamento',
                      child: _loading
                          ? const LoadingPlaceholder(height: 100)
                          : (_reqEmAndamento.isEmpty
                          ? const _EmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'Nenhum requerimento em andamento',
                        subtitle: 'Quando houverem movimentações, elas aparecerão aqui.',
                      )
                          : Column(
                        children: _reqEmAndamento
                            .take(3)
                            .map((e) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.description_outlined),
                          title: Text(
                            e.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Status: ${e.status} • Atualizado: ${fmtData(e.atualizadoEm)}'),
                          trailing: const Icon(Icons.chevron_right),
                        ))
                            .toList(),
                      )),
                    ),
                    const SizedBox(height: 12),

                    // ===== Comunicados
                    SectionCard(
                      title: 'Comunicados',
                      child: _loading
                          ? const LoadingPlaceholder(height: 100)
                          : (_comunicados.isEmpty
                          ? const _EmptyState(
                        icon: Icons.campaign_outlined,
                        title: 'Sem comunicados no momento',
                        subtitle: 'Novos avisos oficiais do IPASEM aparecerão aqui.',
                      )
                          : Column(
                        children: _comunicados
                            .take(3)
                            .map((c) => ListTile(
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
                        ))
                            .toList(),
                      )),
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

// ================== Widgets específicos da Home ==================

class _HeaderCard extends StatelessWidget {
  final bool isLoggedIn;
  final String? cpf;
  final VoidCallback onLogin;
  final VoidCallback onPerfil;

  const _HeaderCard({
    required this.isLoggedIn,
    required this.cpf,
    required this.onLogin,
    required this.onPerfil,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: blockDecoration(),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: kBrand,
            child: Icon(Icons.person_outline, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn ? 'Sessão ativa' : 'Visitante',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (isLoggedIn)
                      const StatusChip(
                        label: 'Acesso completo',
                        color: Color(0xFF027A48),
                        bg: Color(0xFFD1FADF),
                      )
                    else
                      const StatusChip(
                        label: 'Acesso limitado',
                        color: Color(0xFF6941C6),
                        bg: Color(0xFFF4EBFF),
                      ),
                    if (cpf != null && cpf!.isNotEmpty)
                      StatusChip(
                        label: 'CPF: ${fmtCpf(cpf!)}',
                        color: const Color(0xFF475467),
                        bg: const Color(0xFFEFF6F9),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!isLoggedIn)
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: kBrand,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: onLogin,
                          icon: const Icon(Icons.login),
                          label: const Text('Fazer login'),
                        ),
                      )
                    else
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPerfil,
                          icon: const Icon(Icons.person),
                          label: const Text('Ver perfil'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onCarteirinha;
  final VoidCallback onAssistenciaSaude;
  final VoidCallback onAutorizacoes;

  const _QuickActions({
    required this.onCarteirinha,
    required this.onAssistenciaSaude,
    required this.onAutorizacoes,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 520;
        return Container(
          decoration: BoxDecoration(
            color: kPanelBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kPanelBorder, width: 2),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ações rápidas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475467),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ActionTile(
                    title: 'Carteirinha Digital',
                    icon: Icons.badge_outlined,
                    onTap: onCarteirinha,
                    width: isWide ? (c.maxWidth - 12) / 2 : c.maxWidth,
                  ),
                  ActionTile(
                    title: 'Assistência à Saúde',
                    icon: Icons.local_hospital_outlined,
                    onTap: onAssistenciaSaude,
                    width: isWide ? (c.maxWidth - 12) / 2 : c.maxWidth,
                  ),
                  ActionTile(
                    title: 'Autorizações',
                    icon: Icons.medical_information_outlined,
                    onTap: onAutorizacoes,
                    width: isWide ? (c.maxWidth - 12) / 2 : c.maxWidth,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MinhaSituacaoResumo extends StatelessWidget {
  final String vinculo;
  final String plano;
  final int dependentes;

  const _MinhaSituacaoResumo({
    required this.vinculo,
    required this.plano,
    required this.dependentes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ResumoRow(icon: Icons.badge_outlined, label: 'Vínculo', value: vinculo),
        ResumoRow(icon: Icons.medical_services_outlined, label: 'Plano de saúde', value: plano),
        ResumoRow(icon: Icons.group_outlined, label: 'Dependentes', value: '$dependentes'),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF98A2B3)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475467))),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(color: Color(0xFF667085))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
