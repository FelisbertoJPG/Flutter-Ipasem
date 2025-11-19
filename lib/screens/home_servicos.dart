// lib/screens/home_servicos.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../root_nav_shell.dart';
import '../ui/app_shell.dart';

import '../ui/components/exames_pendentes_card.dart';
import '../ui/components/exames_liberados_card.dart';
import '../ui/components/exames_negadas_card.dart';
import '../ui/components/section_card.dart';
import '../ui/components/quick_actions.dart';
import '../ui/components/services_visitor.dart';

import '../ui/utils/webview_warmup.dart';
import '../ui/utils/service_launcher.dart';

import '../controllers/home_servicos_controller.dart'; // (segue importado caso use no futuro)
import '../state/auth_events.dart'; // (idem, não usamos nesta tela após refatoração)

// telas (mantidas)
import 'login_screen.dart';
import 'autorizacao_medica_screen.dart';
import 'autorizacao_odontologica_screen.dart';
import 'autorizacao_exames_screen.dart';
import 'historico_autorizacoes_screen.dart';

// sessão/perfil (para obter a matrícula)
import '../services/session.dart';

// fluxo NOVO da carteirinha (overlay)
import '../screens/carteirinha_flow.dart';

// >>> NOVA TELA: Extrato de Coparticipação
import 'relatorio_coparticipacao_screen.dart';

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

  late final ServiceLauncher launcher = ServiceLauncher(context, takePrewarmed);

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

    // Apenas carrega a matrícula para os fluxos que exigem idmatricula.
    if (_isLoggedIn) {
      try {
        final prof = await Session.getProfile();
        _matricula = prof?.id;
      } catch (_) {
        _matricula = null;
      }
    } else {
      _matricula = null;
    }

    if (mounted) setState(() => _loading = false);
  }

  // ================== Ações de navegação ==================

  List<QuickActionItem> _loggedActions() {
    return [
      QuickActionItem(
        id: 'aut_med',
        label: 'Autorização Médica',
        icon: FontAwesomeIcons.stethoscope,
        onTap: () {
          final scope = RootNavShell.maybeOf(context);
          if (scope != null) {
            scope.pushInServicos('autorizacao-medica');
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AutorizacaoMedicaScreen()),
            );
          }
        },
        audience: QaAudience.loggedIn,
        requiresLogin: false,
      ),
      QuickActionItem(
        id: 'aut_odo',
        label: 'Autorização Odontológica',
        icon: FontAwesomeIcons.tooth,
        onTap: () {
          final scope = RootNavShell.maybeOf(context);
          if (scope != null) {
            scope.pushInServicos('autorizacao-odontologica');
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AutorizacaoOdontologicaScreen()),
            );
          }
        },
        audience: QaAudience.loggedIn,
        requiresLogin: false,
      ),
      QuickActionItem(
        id: 'aut_exames',
        label: 'Autorização de Exames',
        icon: Icons.monitor_heart,
        onTap: () {
          final scope = RootNavShell.maybeOf(context);
          if (scope != null) {
            scope.pushInServicos('autorizacao-exames');
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AutorizacaoExamesScreen()),
            );
          }
        },
        audience: QaAudience.loggedIn,
        requiresLogin: false,
      ),
      QuickActionItem(
        id: 'carteirinha',
        label: 'Carteirinha Digital',
        icon: FontAwesomeIcons.idCard,
        audience: QaAudience.loggedIn,
        requiresLogin: true,
        onTap: () async {
          final m = _matricula;
          if (m == null || m <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Não foi possível carregar a sua matrícula. Faça login novamente.')),
            );
            return;
          }
          await startCarteirinhaFlow(context, idMatricula: m);
        },
      ),

      // >>> NOVOS CAMPOS (deferem o carregamento):
      QuickActionItem(
        id: 'historico_aut',
        label: 'Histórico de Autorizações',
        icon: FontAwesomeIcons.clockRotateLeft,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HistoricoAutorizacoesScreen()),
          );
        },
        audience: QaAudience.loggedIn,
        requiresLogin: true,
      ),
      QuickActionItem(
        id: 'retorno_exames',
        label: 'Retorno de Exames',
        icon: FontAwesomeIcons.listCheck,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _RetornoExamesScreen()),
          );
        },
        audience: QaAudience.loggedIn,
        requiresLogin: true,
      ),

      // >>> NOVA AÇÃO: Extrato de Coparticipação
      QuickActionItem(
        id: 'extrato_copart',
        label: 'Extrato Coparticipação',
        icon: FontAwesomeIcons.fileInvoiceDollar,
        onTap: () {
          final m = _matricula;
          if (m == null || m <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Não foi possível carregar a sua matrícula. Faça login novamente.')),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RelatorioCoparticipacaoScreen(idMatricula: m),
            ),
          );
        },
        audience: QaAudience.loggedIn,
        requiresLogin: true,
      ),

      QuickActionItem(
        id: 'site',
        label: 'Site',
        icon: FontAwesomeIcons.globe,
        onTap: () => launcher.openUrl(HomeServicos._siteUrl, 'Site'),
        audience: QaAudience.all,
        requiresLogin: false,
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

/// Tela interna (somente para retorno de autorizações de exames).
/// Reutiliza os mesmos cards, mas o carregamento só ocorre ao abrir esta tela.
class _RetornoExamesScreen extends StatelessWidget {
  const _RetornoExamesScreen();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Retorno de Autorizações de Exames',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          ExamesPendentesCard(),
          SizedBox(height: 12),
          ExamesLiberadosCard(),
          SizedBox(height: 12),
          ExamesNegadasCard(),
        ],
      ),
    );
  }
}
