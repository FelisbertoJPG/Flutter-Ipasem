import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../root_nav_shell.dart'; // pushInServicos / setTab
import '../ui/app_shell.dart';
import '../ui/components/section_card.dart';
import '../ui/components/quick_actions.dart';
import '../ui/components/services_visitor.dart';
import '../ui/widgets/history_list.dart';
import '../ui/utils/webview_warmup.dart';
import '../ui/utils/service_launcher.dart';

import 'login_screen.dart';
import 'autorizacao_medica_screen.dart'; // fallback opcional
import 'autorizacao_odontologica_screen.dart'; // fallback opcional (novo)

class HomeServicos extends StatefulWidget {
  const HomeServicos({super.key});

  static const String _prefsKeyCpf = 'saved_cpf';

  static const String _loginUrl = 'https://assistweb.ipasemnh.com.br/site/login';
  static const String _siteUrl  = 'https://www.ipasemnh.com.br/home';

  @override
  State<HomeServicos> createState() => _HomeServicosState();
}

class _HomeServicosState extends State<HomeServicos> with WebViewWarmup {
  bool _loading = true;
  bool _isLoggedIn = false;
  List<HistoryItem> _historico = const [];

  late final ServiceLauncher launcher =
  ServiceLauncher(context, takePrewarmed);

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

    _historico = _isLoggedIn
        ? const [
      HistoryItem(title: 'Consulta médica (Clínico Geral)', subtitle: '10/09/2025 • Autorizada'),
      HistoryItem(title: 'Consulta odontológica (Avaliação)', subtitle: '02/09/2025 • Autorizada'),
    ]
        : const [];

    if (mounted) setState(() => _loading = false);
  }

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
            scope.pushInServicos('autorizacao-odontologica'); // <- agora NATIVA
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
        id: 'reimpressao',
        label: 'Reimpressão de Autorizações',
        icon: FontAwesomeIcons.print,
        onTap: () => launcher.openWithCpfPrompt(
          HomeServicos._loginUrl,
          'Reimpressão de Autorizações',
          prefsKeyCpf: HomeServicos._prefsKeyCpf,
        ),
        audience: QaAudience.loggedIn,
        requiresLogin: false,
      ),
      QuickActionItem(
        id: 'carteirinha',
        label: 'Carteirinha Digital',
        icon: FontAwesomeIcons.idCard,
        onTap: () => launcher.openUrl(
          HomeServicos._loginUrl,
          'Carteirinha Digital',
        ),
        audience: QaAudience.loggedIn,
        requiresLogin: false,
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
        const SizedBox(height: 12),
        SectionCard(
          title: 'Histórico de Autorizações',
          child: HistoryList(
            loading: _loading,
            isLoggedIn: false,
            items: const [],
            onSeeAll: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Faça login para acessar o histórico.')),
              );
            },
          ),
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
        const SizedBox(height: 12),
        SectionCard(
          title: 'Histórico de Autorizações',
          child: HistoryList(
            loading: _loading,
            isLoggedIn: true,
            items: _historico,
            onSeeAll: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Implementar tela de histórico completo.')),
              );
            },
          ),
        ),
      ],
    );
  }
}
