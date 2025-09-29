// lib/screens/home_servicos.dart (versão curta)
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/app_shell.dart';
import '../ui/components/section_card.dart';
import '../theme/colors.dart';
import '../ui/utils/webview_warmup.dart';
import '../ui/utils/service_launcher.dart';
import '../ui/widgets/action_grid.dart';
import '../ui/widgets/history_list.dart';

class HomeServicos extends StatefulWidget {
  const HomeServicos({super.key});
  static const String _prefsKeyCpf = 'saved_cpf';
  static const String _loginUrl    = 'https://assistweb.ipasemnh.com.br/site/login';
  static const String _siteUrl     = 'https://www.ipasemnh.com.br/home';

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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Serviços',
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            SectionCard(
              title: 'Serviços em destaque',
              child: ActionGrid(
                items: [
                  ActionItem(
                    title: 'Autorização de Consulta Médica',
                    icon: FontAwesomeIcons.stethoscope,
                    onTap: () => launcher.openWithCpfPrompt(HomeServicos._loginUrl, 'Autorização de Consulta Médica', prefsKeyCpf: HomeServicos._prefsKeyCpf),
                  ),
                  ActionItem(
                    title: 'Autorização de Consulta Odontológica',
                    icon: FontAwesomeIcons.tooth,
                    onTap: () => launcher.openWithCpfPrompt(HomeServicos._loginUrl, 'Autorização de Consulta Odontológica', prefsKeyCpf: HomeServicos._prefsKeyCpf),
                  ),
                  ActionItem(
                    title: 'Reimpressão de Autorizações',
                    icon: FontAwesomeIcons.print,
                    onTap: () => launcher.openWithCpfPrompt(HomeServicos._loginUrl, 'Reimpressão de Autorizações', prefsKeyCpf: HomeServicos._prefsKeyCpf),
                  ),
                  ActionItem(
                    title: 'Carteirinha Digital',
                    icon: FontAwesomeIcons.idCard,
                    onTap: () => launcher.openUrl(HomeServicos._loginUrl, 'Carteirinha Digital'),
                  ),
                  ActionItem(
                    title: 'Site',
                    icon: FontAwesomeIcons.globe,
                    onTap: () => launcher.openUrl(HomeServicos._siteUrl, 'Site'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Histórico de Autorizações',
              child: HistoryList(
                loading: _loading,
                isLoggedIn: _isLoggedIn,
                items: _historico,
                onSeeAll: () {
                  // TODO: navegar para tela de histórico completo
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Implementar tela de histórico completo.')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
