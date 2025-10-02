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
import '../core/formatters.dart'; // fmtCpf, fmtData se quiser
import '../repositories/dependents_repository.dart';
import '../services/dev_api.dart';
import '../config/app_config.dart';

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
    // Inicializa o repo uma única vez, lendo a base da AppConfig (ou dart-define)
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
    } catch (e) {
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
            _HeaderCardVisitor(
              onLogin: _goToLogin,
              onSignUp: _openCreateAccount,
            ),
            const SizedBox(height: 16),
            const _LockedDataBlocks(),
            const SizedBox(height: 24),
            _VisitorHint(),
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

// ================== Widgets ==================

class _HeaderCardVisitor extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  const _HeaderCardVisitor({
    required this.onLogin,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
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
                child: Icon(Icons.person_outline, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Visitante',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatusChip(
                          label: 'Logado como Visitante',
                          color: Color(0xFFB54708),
                          bg: Color(0xFFFFF4E5),
                        ),
                        _StatusChip(
                          label: 'Acesso limitado',
                          color: Color(0xFF6941C6),
                          bg: Color(0xFFF4EBFF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kBrand),
            onPressed: onLogin,
            icon: const Icon(Icons.login),
            label: const Text('Fazer login'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: onSignUp,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Criar conta'),
          ),
        ),
      ],
    );
  }
}

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
                Text(profile.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
              _InfoRow(label: 'Nome completo', value: profile.nome),
              _InfoRow(label: 'CPF', value: fmtCpf(profile.cpf)),
              _InfoRow(label: 'Matrícula', value: profile.id.toString()),
              _InfoRow(label: 'E-mail', value: profile.email ?? '—'),
              _InfoRow(label: 'E-mail 2', value: profile.email2 ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Dependentes',
          child: _DependentsList(
            loading: depsLoading,
            error: depsError,
            items: dependentes ?? const [],
          ),
        ),
      ],
    );
  }
}

class _DependentsList extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<Dependent> items;

  const _DependentsList({
    required this.loading,
    required this.items,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Nenhum dependente encontrado.'),
      );
    }
    return Column(
      children: items.map((d) {
        final cpfTxt = (d.cpf == null || d.cpf!.isEmpty) ? '—' : fmtCpf(d.cpf!);
        final idadeTxt = (d.idade != null) ? '${d.idade} anos' : '—';
        final nascTxt = (d.dtNasc ?? '—'); // se quiser, parse e usar fmtData
        // Se quiser aplicar sua regra de vínculo, ajuste abaixo:
        final vinculo = (d.iddependente <= 0)
            ? 'Dependente'
            : (d.idmatricula == 0 ? 'Titular' : '—');

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.family_restroom_outlined, color: Color(0xFF667085)),
          title: Text(
            d.nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF101828)),
          ),
          subtitle: Text(
            'CPF: $cpfTxt  •  Idade: $idadeTxt  •  Nasc.: $nascTxt',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF475467)),
          ),
          trailing: Text(vinculo, style: const TextStyle(color: Color(0xFF667085))),
          minLeadingWidth: 0,
        );
      }).toList(),
    );
  }
}

class _LockedDataBlocks extends StatelessWidget {
  const _LockedDataBlocks();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SectionCard(
          title: 'Dados do usuário',
          child: Column(
            children: [
              _LockedInfoRow(label: 'Nome completo'),
              _LockedInfoRow(label: 'CPF'),
              _LockedInfoRow(label: 'Matrícula'),
              _LockedInfoRow(label: 'E-mail'),
              _LockedInfoRow(label: 'Telefone'),
              _LockedInfoRow(label: 'Data de nascimento'),
              _LockedInfoRow(label: 'Vínculo / Situação'),
            ],
          ),
        ),
        SizedBox(height: 12),
        SectionCard(
          title: 'Benefícios',
          child: Column(
            children: [
              _LockedInfoRow(label: 'Plano de saúde'),
              _LockedInfoRow(label: 'Dependentes'),
              _LockedInfoRow(label: 'Autorizações recentes'),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisitorHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPanelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPanelBorder),
      ),
      child: const Text(
        'Você está logado como Visitante. Faça login para visualizar seus dados '
            'pessoais e informações de benefícios.',
        style: TextStyle(color: Color(0xFF475467)),
      ),
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
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LockedInfoRow extends StatelessWidget {
  final String label;

  const _LockedInfoRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.lock_outline, color: Color(0xFF667085)),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF101828)),
      ),
      subtitle: const Text(
        'Disponível após login',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Color(0xFF667085)),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
      minLeadingWidth: 0,
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
