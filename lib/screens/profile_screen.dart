// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/colors.dart';
import '../ui/app_shell.dart';
import '../ui/components/section_card.dart';
import '../screens/login_screen.dart';

import '../services/session.dart';
import '../models/profile.dart';
import '../models/dependent.dart';
import '../core/formatters.dart';
import '../repositories/dependents_repository.dart';
import '../services/dev_api.dart';
import '../config/app_config.dart';

// cards reutilizáveis
import '../ui/components/dependents_card.dart';
import '../ui/components/visitor_profile_view.dart';

const _createAccountUrl =
    'https://assistweb.ipasemnh.com.br/requerimentos/recuperar-senha-prestador';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Profile? _profile;
  bool _loading = true;

  // Dependentes (estado)
  List<Dependent> _deps = const [];
  bool _depsLoading = false;
  String? _depsError;

  // Repo de dependentes
  late DependentsRepository _depsRepo;
  bool _depsReady = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
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

  Future<void> _loadSession() async {
    final p = await Session.getProfile();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _loading = false;
    });
    if (p != null) {
      _fetchDependentes(p.id);
    }
  }

  Future<void> _fetchDependentes(int idMatricula) async {
    setState(() {
      _depsLoading = true;
      _depsError = null;
    });
    try {
      final rows = await _depsRepo.listByMatricula(idMatricula);
      if (!mounted) return;
      setState(() => _deps = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _depsError = 'Falha ao carregar dependentes');
    } finally {
      if (mounted) setState(() => _depsLoading = false);
    }
  }

  void _fallbackSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _goToLogin() {
    FocusScope.of(context).unfocus();
    try {
      Navigator.of(context, rootNavigator: true).pushNamed('/login');
    } catch (_) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _logout() async {
    try {
      await Session.logout();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (_) {
      if (!mounted) return;
      _fallbackSnack('Não foi possível encerrar a sessão.');
    }
  }

  Future<void> _openCreateAccount() async {
    try {
      final ok = await launchUrl(
        Uri.parse(_createAccountUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception();
    } catch (_) {
      if (!mounted) return;
      _fallbackSnack('Não foi possível abrir o link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AppScaffold(
      title: 'Perfil',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_profile == null) ...[
            // <<< visão de visitante centralizada
            VisitorProfileView(
              onLogin: _goToLogin,
              onSignUp: _openCreateAccount,
            ),
          ] else ...[
            _HeaderCardUser(profile: _profile!, onLogout: _logout),
            const SizedBox(height: 16),
            _UserDataBlocks(
              profile: _profile!,
              dependentes: _deps,
              depsLoading: _depsLoading,
              depsError: _depsError,
            ),
          ],
        ],
      ),
    );
  }
}

// ================== Widgets (apenas os da visão logada) ==================

class _HeaderCardUser extends StatelessWidget {
  final Profile profile;
  final VoidCallback onLogout;

  const _HeaderCardUser({required this.profile, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: kBrand,
            child: Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StatusChip(
                      label: 'Acesso autenticado',
                      color: Color(0xFF027A48),
                      bg: Color(0xFFD1FADF),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kBrand, width: 1.4),
              foregroundColor: kBrand,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserDataBlocks extends StatelessWidget {
  final Profile profile;
  final List<Dependent>? dependentes;
  final bool depsLoading;
  final String? depsError;

  const _UserDataBlocks({
    required this.profile,
    this.dependentes,
    this.depsLoading = false,
    this.depsError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionCard(
          title: 'Dados do usuário',
          child: Column(
            children: [
              _InfoRow(label: 'Nome completo ', value: profile.nome),
              _InfoRow(label: 'CPF', value: fmtCpf(profile.cpf)),
              _InfoRow(label: 'Matrícula', value: profile.id.toString()),
              _InfoRow(label: 'E-mail', value: profile.email ?? '—'),
              _InfoRow(label: 'E-mail 2', value: profile.email2 ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Card de dependentes (reutilizável)
        DependentsCard(
          items: dependentes ?? const [],
          isLoading: depsLoading,
          error: depsError,
          compact: true,
          showDivider: true,
          showMatricula: true,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline, color: Color(0xFF667085)),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF101828)),
      ),
      subtitle: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF475467)),
      ),
      minLeadingWidth: 0,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _StatusChip({required this.label, required this.color, required this.bg});

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
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
