// lib/screens/home_servicos.dart
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

import '../config/app_config.dart';
import '../services/dev_api.dart';
import '../services/session.dart';                   // <<< ADICIONADO
import '../repositories/reimpressao_repository.dart';
import '../models/reimpressao.dart';

import 'login_screen.dart';
import 'autorizacao_medica_screen.dart';
import 'autorizacao_odontologica_screen.dart';

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

  // histórico exibido no card (HistoryList usa HistoryItem)
  List<HistoryItem> _historico = const [];

  // dados crus vindos da API (para usar no onTap -> detalhe)
  List<ReimpressaoResumo> _histRows = const [];

  late final ServiceLauncher launcher = ServiceLauncher(context, takePrewarmed);
  ReimpressaoRepository? _reimpRepo;

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

    _historico = const [];
    _histRows  = const [];

    if (_isLoggedIn) {
      try {
        final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
            ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');
        final api  = DevApi(baseUrl);
        _reimpRepo = ReimpressaoRepository(api);

        final profile = await Session.getProfile();          // pega id
        if (profile != null) {
          _histRows = await _reimpRepo!.historico(idMatricula: profile.id); // envia id
          _historico = _histRows.map((h) {
            final titulo = h.prestadorExec.isNotEmpty ? h.prestadorExec : 'Autorização ${h.numero}';
            final sub = [
              if (h.dataEmissao.isNotEmpty && h.horaEmissao.isNotEmpty)
                '${h.dataEmissao} • ${h.horaEmissao}'
              else if (h.dataEmissao.isNotEmpty)
                h.dataEmissao,
              if (h.paciente.isNotEmpty) '• ${h.paciente}',
            ].join(' ');
            return HistoryItem(title: titulo, subtitle: sub, onTap: () => _onTapHistorico(h));
          }).toList();
        }
      } catch (_) {
        _historico = const [];
        _histRows  = const [];
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  // ações (logado)
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

  // tap em um item do histórico -> dialog com opções
  Future<void> _onTapHistorico(ReimpressaoResumo a) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reimpressão da Ordem'),
        content: Text('Deseja imprimir a ordem ${a.numero}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _showDetalhes(a.numero);
            },
            child: const Text('Ver detalhes'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              launcher.openUrl(HomeServicos._loginUrl, 'Reimpressão de Autorizações');
            },
            child: const Text('Imprimir (site)'),
          ),
        ],
      ),
    );
  }

  // bottom sheet de detalhes (APENAS UMA VERSÃO)
  Future<void> _showDetalhes(int numero) async {
    if (_reimpRepo == null) return;
    final profile = await Session.getProfile();

    ReimpressaoDetalhe? det;
    try {
      det = await _reimpRepo!.detalhe(numero, idMatricula: profile?.id); // envia id opcional
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        if (det == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Não foi possível carregar os detalhes.'),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE5EE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Dados da Autorização',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _kv('Número', '${det!.numero}'),
              _kv('Paciente', det.nomePaciente),
              _kv('Prestador', det.nomePrestadorExec),
              _kv('Especialidade', det.nomeEspecialidade),
              _kv('Data de Emissão', det.dataEmissao),
              const Divider(height: 24),
              _kv('Endereço', det.enderecoComl),
              _kv('Bairro/Cidade', '${det.bairroComl} - ${det.cidadeComl}'),
              if (det.telefoneComl.trim().isNotEmpty) _kv('Telefone', det.telefoneComl),
              if (det.observacoes.trim().isNotEmpty) ...[
                const Divider(height: 24),
                _kv('Observações', det.observacoes),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.print),
                onPressed: () {
                  Navigator.of(context).pop();
                  launcher.openUrl(HomeServicos._loginUrl, 'Reimpressão de Autorizações');
                },
                label: const Text('Imprimir via site'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 140, child: Text(k, style: const TextStyle(color: Colors.black54))),
        const SizedBox(width: 8),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    ),
  );

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

  // ====== VISITOR VIEW ======
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

  // ====== MEMBER VIEW ======
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
              // ponto de expansão futuro (tela de histórico completo)
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
