// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';      // para logout e CTA de login
import 'service_screen.dart';    // tela de Serviços (carteirinha / assistência)
import 'profile_screen.dart';    // tela de Perfil (auto explicativa)

// ====== Paleta / estilos base (alinhada com demais telas) ======
const _brand       = Color(0xFF143C8D);
const _cardBg      = Color(0xFFEFF6F9);
const _cardBorder  = Color(0xFFE2ECF2);
const _panelBg     = Color(0xFFF4F5F7);
const _panelBorder = Color(0xFFE5E8EE);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  // ---- Estado básico / sessão ----
  bool _loading = true;
  bool _isLoggedIn = false; // Visitante por padrão
  String? _cpf;

  // ---- Exemplo de dados dinâmicos (stubs) ----
  List<_RequerimentoResumo> _reqEmAndamento = const [];
  List<_ComunicadoResumo> _comunicados = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();

    // Enquanto não houver login real, isso naturalmente cai em false (Visitante)
    final logged = prefs.getBool('is_logged_in') ?? false;
    final cpf = prefs.getString('saved_cpf');

    // Stubs iniciais (em produção, troque por chamadas HTTP)
    final req = <_RequerimentoResumo>[];
    final avisos = <_ComunicadoResumo>[
      _ComunicadoResumo(
        titulo: 'Manutenção programada',
        descricao:
        'Sistema de autorizações ficará indisponível no domingo, 02:00–04:00.',
        data: DateTime.now(),
      ),
      _ComunicadoResumo(
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

  Future<void> _logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_cpf');
      await prefs.remove('auth_token');
      await prefs.setBool('is_logged_in', false);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível encerrar a sessão.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: const [
          _LogoAction(
            imagePath: 'assets/images/icons/logo_ipasem.png',
            size: 28,
            borderRadius: 6,
          ),
          SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                child: Text(
                  'Menu',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.grid_view_rounded),
                title: const Text('Serviços'),
                onTap: () {
                  Navigator.of(context).pop();
                  _goToServicos();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Perfil'),
                onTap: () {
                  Navigator.of(context).pop();
                  _goToPerfil();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sair'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _logout(context);
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
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
                        onPerfil: _goToPerfil,
                      ),
                      const SizedBox(height: 16),

                      // ===== Ações rápidas (levam à tela de Serviços)
                      _QuickActions(
                        onCarteirinha: _goToServicos,
                        onAssistenciaSaude: _goToServicos,
                        onAutorizacoes: _goToServicos,
                      ),
                      const SizedBox(height: 16),

                      // ===== Minha Situação
                      _SectionCard(
                        title: 'Minha Situação',
                        child: _loading
                            ? const _LoadingPlaceholder(height: 72)
                            : _isLoggedIn
                            ? const _MinhaSituacaoResumo(
                          vinculo: 'Ativo',
                          plano: 'Plano Saúde IPASEM',
                          dependentes: 2,
                        )
                            : const _LockedNotice(
                          message:
                          'Faça login para visualizar seus dados de vínculo, plano e dependentes.',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ===== Em andamento (Requerimentos)
                      _SectionCard(
                        title: 'Requerimentos em andamento',
                        child: _loading
                            ? const _LoadingPlaceholder(height: 100)
                            : (_reqEmAndamento.isEmpty
                            ? const _EmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'Nenhum requerimento em andamento',
                          subtitle:
                          'Quando houverem movimentações, elas aparecerão aqui.',
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
                            subtitle: Text(
                              'Status: ${e.status} • Atualizado: ${_fmtData(e.atualizadoEm)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ))
                              .toList(),
                        )),
                      ),
                      const SizedBox(height: 12),

                      // ===== Comunicados
                      _SectionCard(
                        title: 'Comunicados',
                        child: _loading
                            ? const _LoadingPlaceholder(height: 100)
                            : (_comunicados.isEmpty
                            ? const _EmptyState(
                          icon: Icons.campaign_outlined,
                          title: 'Sem comunicados no momento',
                          subtitle:
                          'Novos avisos oficiais do IPASEM aparecerão aqui.',
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
                              '${_fmtData(c.data)} • ${c.descricao}',
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
      ),
    );
  }
}

// ================== Widgets de composição ==================

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
      decoration: _blockDecoration(),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _brand,
            child: const Icon(Icons.person_outline, color: Colors.white),
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
                      const _StatusChip(
                        label: 'Acesso completo',
                        color: Color(0xFF027A48),
                        bg: Color(0xFFD1FADF),
                      )
                    else
                      const _StatusChip(
                        label: 'Acesso limitado',
                        color: Color(0xFF6941C6),
                        bg: Color(0xFFF4EBFF),
                      ),
                    if (cpf != null && cpf!.isNotEmpty)
                      _StatusChip(
                        label: 'CPF: ${_fmtCpf(cpf!)}',
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
                            backgroundColor: _brand,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: onLogin,
                          icon: const Icon(Icons.login),
                          label: const Text('Fazer login'),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPerfil,
                          icon: const Icon(Icons.person),
                          label: const Text('Ver perfil'),
                        ),
                      ),
                    ],
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

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bg),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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
            color: _panelBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _panelBorder, width: 2),
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
                  _ActionTile(
                    title: 'Carteirinha Digital',
                    icon: Icons.badge_outlined,
                    onTap: onCarteirinha,
                    width: isWide ? (c.maxWidth - 12) / 2 : c.maxWidth,
                  ),
                  _ActionTile(
                    title: 'Assistência à Saúde',
                    icon: Icons.local_hospital_outlined,
                    onTap: onAssistenciaSaude,
                    width: isWide ? (c.maxWidth - 12) / 2 : c.maxWidth,
                  ),
                  _ActionTile(
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

class _ActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final double width;

  const _ActionTile({
    required this.title,
    required this.icon,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _cardBg,
          foregroundColor: const Color(0xFF101828),
          minimumSize: const Size.fromHeight(64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _cardBorder, width: 2),
          ),
          shadowColor: Colors.black12,
        ),
        onPressed: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _cardBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 24, color: _brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF101828),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: _brand),
          ],
        ),
      ),
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
        _ResumoRow(
          icon: Icons.badge_outlined,
          label: 'Vínculo',
          value: vinculo,
        ),
        _ResumoRow(
          icon: Icons.medical_services_outlined,
          label: 'Plano de saúde',
          value: plano,
        ),
        _ResumoRow(
          icon: Icons.group_outlined,
          label: 'Dependentes',
          value: '$dependentes',
        ),
      ],
    );
  }
}

class _ResumoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ResumoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF667085)),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF101828),
        ),
      ),
      trailing: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF101828),
        ),
      ),
      minLeadingWidth: 0,
    );
  }
}

class _LockedNotice extends StatelessWidget {
  final String message;

  const _LockedNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFF667085)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF475467)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _blockDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF475467),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
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
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  final double height;

  const _LoadingPlaceholder({this.height = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

// ================== Helpers / modelos ==================

BoxDecoration _blockDecoration() => BoxDecoration(
  color: _cardBg,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: _cardBorder, width: 2),
);

String _fmtData(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year.toString();
  return '$dd/$mm/$yyyy';
}

String _fmtCpf(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  if (d.length != 11) return digits; // evita substring range error em dados inválidos
  return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
}

class _RequerimentoResumo {
  final String titulo;
  final String status;
  final DateTime atualizadoEm;

  const _RequerimentoResumo({
    required this.titulo,
    required this.status,
    required this.atualizadoEm,
  });
}

class _ComunicadoResumo {
  final String titulo;
  final String descricao;
  final DateTime data;

  const _ComunicadoResumo({
    required this.titulo,
    required this.descricao,
    required this.data,
  });
}

/// Ação de AppBar que garante que qualquer imagem seja contida no quadrado,
/// recortada sem deformar (BoxFit.cover + ClipRRect).
class _LogoAction extends StatelessWidget {
  final String imagePath;
  final double size;
  final double borderRadius;

  const _LogoAction({
    super.key,
    required this.imagePath,
    this.size = 28,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
