// lib/screens/home_servicos.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../common/config/dev_api.dart';
import '../../../common/services/session.dart';
import '../../../common/models/dependent.dart';
import '../../../common/config/api_router.dart';
import '../../../common/repositories/dependents_repository.dart';

import '../components/quick_actions.dart';
import '../components/cards/section_card.dart';
import '../components/services_visitor.dart';
import '../layouts/app_shell.dart';
import '../components/acoes_rapidas_comp/quick_action_items.dart';
import '../ui/utils/service_launcher.dart';
import '../ui/utils/webview_warmup.dart';
import 'login_screen.dart';

class HomeServicos extends StatefulWidget {
  const HomeServicos({super.key});

  static const String _loginUrl = 'https://assistweb.ipasemnh.com.br/site/login';
  static const String _siteUrl  = 'https://www.ipasemnh.com.br/home';

  @override
  State<HomeServicos> createState() => _HomeServicosState();
}

class _HomeServicosState extends State<HomeServicos> with WebViewWarmup {
  bool _loading = true;
  bool _isLoggedIn = false;

  int? _matricula; // usada para emissão da carteirinha e relatórios

  /// Indica se o login atual é de DEPENDENTE (não titular).
  bool _isDependentLogin = false;

  late final ServiceLauncher launcher =
  ServiceLauncher(context, takePrewarmed);

  // Repositório para detectar se o login atual é de dependente
  late final DependentsRepository _depsRepo =
  DependentsRepository(DevApi());

  @override
  void initState() {
    super.initState();
    warmupInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    _matricula = null;
    _isDependentLogin = false;

    if (_isLoggedIn) {
      try {
        final prof = await Session.getProfile();
        if (prof != null) {
          _matricula = prof.id;

          // === DETECÇÃO DE LOGIN DE DEPENDENTE ============================
          //
          // Regra: se dentro desta matrícula existir um dependente
          // (iddependente != 0) com CPF igual ao CPF do profile,
          // consideramos que o login é de dependente.
          try {
            List<Dependent> deps = const [];
            try {
              deps = await _depsRepo.listByMatricula(prof.id);
            } catch (_) {
              deps = const [];
            }

            final cpfPerfilDigits =
            (prof.cpf ?? '').replaceAll(RegExp(r'\D'), '');

            for (final d in deps) {
              final dc = d.cpf;
              if (dc == null || dc.isEmpty) continue;
              final dcDigits = dc.replaceAll(RegExp(r'\D'), '');
              if (d.iddependente != 0 && dcDigits == cpfPerfilDigits) {
                _isDependentLogin = true;
                break;
              }
            }
          } catch (_) {
            // Em caso de erro na detecção, mantemos _isDependentLogin = false
          }
          // ================================================================
        }
      } catch (_) {
        _matricula = null;
      }
    } else {
      _matricula = null;
      _isDependentLogin = false;
    }

    if (mounted) setState(() => _loading = false);
  }

  // ================== Ações de navegação ==================

  List<QuickActionItem> _loggedActions() {
    final m = _matricula;

    return [
      QuickActionItems.autorizacaoMedica(context: context),
      QuickActionItems.autorizacaoOdontologica(context: context),
      QuickActionItems.autorizacaoExames(context: context),
      QuickActionItems.carteirinha(
        context: context,
        idMatricula: m,
      ),
      QuickActionItems.historicoAutorizacoes(
        context: context,
      ),
      QuickActionItems.retornoExames(
        context: context,
      ),

      // Extrato de coparticipação APENAS para TITULAR
      if (!_isDependentLogin)
        QuickActionItems.extratoCoparticipacao(
          context: context,
          idMatricula: m,
        ),

      QuickActionItems.site(
        onTap: () => launcher.openUrl(HomeServicos._siteUrl, 'Site'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : (_isLoggedIn ? _buildMemberView() : _buildVisitorView());

    return AppScaffold(
      title: 'Serviços',
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [body],
        ),
      ),
    );
  }

  Widget _buildVisitorView() {
    return Column(
      children: [
        ServicesVisitors(
          onLoginTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMemberView() {
    return Column(
      children: [
        SectionCard(
          title: 'Serviços em destaque',
          child: QuickActions(
            title: null,
            items: _loggedActions(),
            isLoggedIn: true,
            onRequireLogin: null,
          ),
        ),
        // Removidos: ExamesPendentes/ExamesLiberados/ExamesNegadas e Histórico na home.
        // Agora esses conteúdos são carregados SOMENTE quando o usuário toca nos
        // atalhos “Histórico de Autorizações” e “Retorno de Exames”.
      ],
    );
  }
}
