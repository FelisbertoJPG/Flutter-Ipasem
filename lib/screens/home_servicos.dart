// lib/screens/home_servicos.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pdf_preview_screen.dart';           // abre o PDF dentro do app
import '../pdf/pdf_mappers.dart';           // mapDetalheToPdfData

import '../root_nav_shell.dart';            // pushInServicos / setTab
import '../ui/app_shell.dart';
import '../ui/components/section_card.dart';
import '../ui/components/quick_actions.dart';
import '../ui/components/services_visitor.dart';
import '../ui/widgets/history_list.dart';
import '../ui/utils/webview_warmup.dart';
import '../ui/utils/service_launcher.dart';

import '../config/app_config.dart';
import '../services/dev_api.dart';
import '../services/session.dart';
import '../repositories/reimpressao_repository.dart';
import '../models/reimpressao.dart';

import 'login_screen.dart';
import 'autorizacao_medica_screen.dart';
import 'autorizacao_odontologica_screen.dart';

/// Ações do action sheet
enum _ReimpAction { detalhes, abrirServidor, baixarServidor, pdfLocal }

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
  List<ReimpressaoResumo> _histRows = const [];

  late final ServiceLauncher launcher = ServiceLauncher(context, takePrewarmed);
  ReimpressaoRepository? _reimpRepo;

  @override
  void initState() {
    super.initState();
    warmupInit();
    _bootstrap();
  }

  // ---------- HELPERS DE DEBUG ----------
  String _appendDebugQuery(String url) {
    final u = Uri.parse(url);
    final qp = Map<String, String>.from(u.queryParameters);
    qp['debug'] = '1';
    return u.replace(queryParameters: qp).toString();
  }

  void _logPdfCall({
    required String where, // "open" | "download" | "local"
    required int numero,
    required int idMatricula,
    required String nomeTitular,
    String? url,
  }) {
    debugPrint('[PDF][$where] numero=$numero idmatricula=$idMatricula '
        'nome_titular="$nomeTitular"${url != null ? ' url=$url' : ''}');
  }
  // --------------------------------------

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

        final profile = await Session.getProfile();
        if (profile != null) {
          _histRows = await _reimpRepo!.historico(idMatricula: profile.id);
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
      } catch (e) {
        _historico = const [];
        _histRows  = const [];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao carregar histórico: $e')),
          );
        }
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

  // ====== ACTION SHEET (responsivo/rolável) ======
  Future<_ReimpAction?> _showReimpActionSheet(ReimpressaoResumo a) {
    return showModalBottomSheet<_ReimpAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final textTheme = Theme.of(ctx).textTheme;
        final muted = textTheme.bodySmall?.copyWith(color: Colors.black54);

        Widget item({
          required IconData icon,
          required String title,
          String? subtitle,
          required _ReimpAction action,
        }) {
          return ListTile(
            leading: Icon(icon),
            title: Text(title, style: textTheme.bodyLarge),
            subtitle: subtitle != null ? Text(subtitle, style: muted) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(ctx).pop<_ReimpAction>(action),
            visualDensity: VisualDensity.compact,
          );
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.40,
          minChildSize: 0.30,
          maxChildSize: 0.90,
          builder: (_, controller) {
            return SafeArea(
              top: false,
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  Text(
                    'Reimpressão da Ordem',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Deseja imprimir a ordem ${a.numero}?', style: muted),
                  const SizedBox(height: 12),

                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE6E9ED)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        item(
                          icon: Icons.info_outline,
                          title: 'Ver detalhes',
                          subtitle: (a.prestadorExec.isNotEmpty || a.paciente.isNotEmpty)
                              ? [a.prestadorExec, a.paciente]
                              .where((s) => s.isNotEmpty)
                              .join(' • ')
                              : null,
                          action: _ReimpAction.detalhes,
                        ),
                        const Divider(height: 1),
                        item(
                          icon: Icons.picture_as_pdf_outlined,
                          title: 'PDF no app',
                          subtitle: 'Pré-visualizar e imprimir no aplicativo',
                          action: _ReimpAction.pdfLocal,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // tap em um item do histórico -> abre action sheet e executa ação escolhida
  Future<void> _onTapHistorico(ReimpressaoResumo a) async {
    if (!mounted) return;

    final action = await _showReimpActionSheet(a);
    if (action == null) return;

    final profile = await Session.getProfile();
    if (profile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter o perfil do usuário.')),
      );
      return;
    }

    switch (action) {
      case _ReimpAction.detalhes:
        await _showDetalhes(a.numero, pacienteFallback: a.paciente.isNotEmpty ? a.paciente : null);
        break;

      case _ReimpAction.abrirServidor:
        if (_reimpRepo == null) return;
        var url = _reimpRepo!.pdfUrl(
          numero: a.numero,
          idMatricula: profile.id,
          nomeTitular: profile.nome,
          download: false,
        );
        if (!kReleaseMode) url = _appendDebugQuery(url);
        _logPdfCall(where: 'open', numero: a.numero, idMatricula: profile.id, nomeTitular: profile.nome, url: url);
        launcher.openUrl(url, 'Ordem ${a.numero}');
        break;

      case _ReimpAction.baixarServidor:
        if (_reimpRepo == null) return;
        var url = _reimpRepo!.pdfUrl(
          numero: a.numero,
          idMatricula: profile.id,
          nomeTitular: profile.nome,
          download: true,
        );
        if (!kReleaseMode) url = _appendDebugQuery(url);
        _logPdfCall(where: 'download', numero: a.numero, idMatricula: profile.id, nomeTitular: profile.nome, url: url);
        launcher.openUrl(url, 'Baixar Ordem ${a.numero}');
        break;

      case _ReimpAction.pdfLocal:
        await _generateLocalPdf(numero: a.numero);
        break;
    }
  }

  // Gera PDF localmente e abre a tela interna de pré-visualização (PdfPreviewScreen)
  Future<void> _generateLocalPdf({required int numero}) async {
    try {
      if (_reimpRepo == null) return;
      final profile = await Session.getProfile();
      if (profile == null) return;

      final det = await _reimpRepo!.detalhe(numero, idMatricula: profile.id);
      if (det == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível carregar os detalhes desta ordem.')),
        );
        return;
      }

      _logPdfCall(where: 'local', numero: numero, idMatricula: profile.id, nomeTitular: profile.nome);

      final data = mapDetalheToPdfData(
        det: det,
        idMatricula: profile.id,
        nomeTitular: profile.nome,
        procedimentos: const [],
      );

      final fileName = 'ordem_${det.numero}.pdf';

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            data: data,
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao gerar PDF no app: $e')),
      );
    }
  }

  // ====== DETALHES (scrollável + paciente com fallback) ======
  Future<void> _showDetalhes(int numero, {String? pacienteFallback}) async {
    if (_reimpRepo == null) return;
    final profile = await Session.getProfile();

    ReimpressaoDetalhe? det;
    try {
      det = await _reimpRepo!.detalhe(numero, idMatricula: profile?.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar detalhes: $e')),
        );
      }
    }
    if (!mounted) return;

    if (det == null) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (_) => const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Não foi possível carregar os detalhes.'),
        ),
      );
      return;
    }

    final d = det;
    final paciente = (d.nomePaciente.trim().isNotEmpty)
        ? d.nomePaciente
        : (pacienteFallback?.trim().isNotEmpty ?? false)
        ? pacienteFallback!.trim()
        : (profile?.nome ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (ctx, controller) {
            final theme = Theme.of(ctx);
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: ListView(
                  controller: controller,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCE5EE),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Dados da Autorização',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),

                    _kv('Número', '${d.numero}'),
                    _kv('Paciente', paciente),
                    _kv('Prestador', d.nomePrestadorExec),
                    _kv('Especialidade', d.nomeEspecialidade),
                    _kv('Data de Emissão', d.dataEmissao),

                    const Divider(height: 24),

                    _kv('Endereço', d.enderecoComl),
                    _kv(
                      'Bairro/Cidade',
                      [
                        if (d.bairroComl.isNotEmpty) d.bairroComl,
                        if (d.cidadeComl.isNotEmpty) d.cidadeComl,
                      ].where((s) => s.isNotEmpty).join(' - '),
                    ),
                    if (d.telefoneComl.trim().isNotEmpty) _kv('Telefone', d.telefoneComl),

                    if (d.observacoes.trim().isNotEmpty) ...[
                      const Divider(height: 24),
                      _kv('Observações', d.observacoes),
                    ],

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.print),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        launcher.openUrl(HomeServicos._loginUrl, 'Reimpressão de Autorizações');
                      },
                      label: const Text('Imprimir via site'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Linha chave/valor responsiva: a largura do rótulo se adapta ao espaço.
  Widget _kv(String k, String v) => LayoutBuilder(
    builder: (context, constraints) {
      final total = constraints.maxWidth;
      // 34% do espaço para o rótulo, mas com limites.
      final labelW = total.clamp(280, 9999) == total
          ? 120.0
          : (total * 0.34).clamp(110.0, 160.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelW,
              child: Text(k, style: const TextStyle(color: Colors.black54)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(fontWeight: FontWeight.w600),
                softWrap: true,
              ),
            ),
          ],
        ),
      );
    },
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
