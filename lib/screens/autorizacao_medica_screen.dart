import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../ui/app_shell.dart';
import '../ui/components/section_card.dart';
import '../ui/components/loading_placeholder.dart';
import '../ui/components/app_alert.dart';

import '../config/app_config.dart';
import '../services/dev_api.dart';
import '../repositories/dependents_repository.dart';
import '../repositories/especialidades_repository.dart';
import '../repositories/prestadores_repository.dart';
import '../repositories/autorizacoes_repository.dart';
// >>> IMPORTS adicionados para abrir o preview a partir do número
import '../repositories/reimpressao_repository.dart';
import '../pdf/pdf_mappers.dart';
import '../pdf/autorizacao_pdf_data.dart';
import 'pdf_preview_screen.dart';

import '../services/session.dart';
import '../models/dependent.dart';
import '../models/especialidade.dart';
import '../models/prestador.dart';

class AutorizacaoMedicaScreen extends StatefulWidget {
  const AutorizacaoMedicaScreen({super.key});

  @override
  State<AutorizacaoMedicaScreen> createState() => _AutorizacaoMedicaScreenState();
}

class _AutorizacaoMedicaScreenState extends State<AutorizacaoMedicaScreen> {
  static const String _version = 'AutorizacaoMedicaScreen v1.3.5';

  bool _loading = true;
  String? _error;
  bool _saving = false;

  bool _loadingCidades = false;
  bool _loadingPrestadores = false;

  _Beneficiario? _selBenef;
  Especialidade? _selEsp;
  String? _selCidade;
  PrestadorRow? _selPrest;

  List<_Beneficiario> _beneficiarios = const [];
  List<Especialidade> _especialidades = const [];
  List<String> _cidades = const [];
  List<PrestadorRow> _prestadores = const [];

  bool _reposReady = false;
  late DevApi _api;
  late DependentsRepository _depsRepo;
  late EspecialidadesRepository _espRepo;
  late PrestadoresRepository _prestRepo;
  late AutorizacoesRepository _autRepo;

  int _toInt(dynamic v) {
    if (v is int) return v;
    final s = v?.toString().trim() ?? '';
    final n = int.tryParse(s);
    if (n == null) throw const FormatException('valor inválido');
    return n;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reposReady) return;

    final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
        ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');

    _api       = DevApi(baseUrl);
    _depsRepo  = DependentsRepository(_api);
    _espRepo   = EspecialidadesRepository(_api);
    _prestRepo = PrestadoresRepository(_api);
    _autRepo   = AutorizacoesRepository(_api);

    _reposReady = true;
    if (kDebugMode) debugPrint(_version);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() { _loading = true; _error = null; });

    try {
      final profile = await Session.getProfile();
      if (profile == null) {
        _error = 'Faça login para solicitar autorização.';
      } else {
        List<Dependent> rows = const [];
        try { rows = await _depsRepo.listByMatricula(profile.id); } catch (_) {}

        final hasTitular = rows.any((d) => d.iddependente == 0);
        if (!hasTitular) {
          rows = [
            Dependent(nome: profile.nome, idmatricula: profile.id, iddependente: 0, cpf: profile.cpf),
            ...rows,
          ];
        }
        _beneficiarios = rows
            .map((d) => _Beneficiario(idMat: d.idmatricula, idDep: d.iddependente, nome: d.nome))
            .toList()
          ..sort((a, b) {
            if (a.idDep == 0 && b.idDep != 0) return -1;
            if (a.idDep != 0 && b.idDep == 0) return 1;
            return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
          });
        _selBenef = _beneficiarios.firstOrNull;
      }

      try {
        _especialidades = await _espRepo.listar();
      } catch (e) {
        if (kDebugMode) print('especialidades erro: $e');
        _especialidades = const [];
      }

      _selEsp = null;
      _cidades = const [];
      _selCidade = null;
      _prestadores = const [];
      _selPrest = null;
    } catch (e) {
      _error = kDebugMode ? 'Falha ao carregar dados. ($e)' : 'Falha ao carregar dados.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCidades() async {
    if (_selEsp == null) return;
    setState(() {
      _loadingCidades = true;
      _cidades = const [];
      _selCidade = null;
      _prestadores = const [];
      _selPrest = null;
    });
    try {
      final rows = await _prestRepo.cidadesDisponiveis(_selEsp!.id);
      setState(() {
        _cidades = rows;
        _loadingCidades = false;
      });
    } catch (e) {
      setState(() { _loadingCidades = false; _cidades = const []; });
      if (!mounted) return;
      AppAlert.toast(context, kDebugMode ? 'Falha ao carregar cidades. ($e)' : 'Falha ao carregar cidades.');
    }
  }

  Future<void> _loadPrestadores() async {
    if (_selEsp == null) return;
    setState(() {
      _loadingPrestadores = true;
      _prestadores = const [];
      _selPrest = null;
    });
    try {
      final cidade = (_selCidade == null || _selCidade == 'TODAS AS CIDADES') ? null : _selCidade;
      final rows = await _prestRepo.porEspecialidade(_selEsp!.id, cidade: cidade);
      setState(() {
        _prestadores = rows;
        _loadingPrestadores = false;
      });
    } catch (e) {
      setState(() { _loadingPrestadores = false; _prestadores = const []; });
      AppAlert.toast(
        context,
        kDebugMode ? 'Falha ao carregar prestadores. ($e)' : 'Falha ao carregar prestadores.',
      );
    }
  }

  bool get _formOk =>
      _selBenef != null && _selEsp != null && _selCidade != null && _selPrest != null;

  Future<void> _onSubmit() async {
    if (!_formOk || _saving) return;

    setState(() => _saving = true);
    try {
      final numero = await _autRepo.gravar(
        idMatricula:     _selBenef!.idMat,
        idDependente:    _selBenef!.idDep,
        idEspecialidade: _toInt(_selEsp!.id),
        idPrestador:     _toInt(_selPrest!.registro),
        tipoPrestador:   _selPrest!.tipoPrestador,
      );

      // limpa seleção para um novo fluxo
      setState(() {
        _selEsp = null;
        _selCidade = null;
        _selPrest = null;
        _cidades = const [];
        _prestadores = const [];
      });

      if (!mounted) return;

      // >>> Card com número + atalho "Abrir impressão" (preview no app)
      await AppAlert.showAuthNumber(
        context,
        numero: numero,
        useRootNavigator: false, // dialog dentro do navigator da aba
        onOpenPreview: () => _openPreviewFromNumero(numero),
        onOk: _goBackToServicos,
      );
    } on FormatException {
      if (!mounted) return;
      await AppAlert.show(
        context,
        title: 'Dados inválidos',
        message: 'Dados inválidos para emissão.',
        type: AppAlertType.error,
        useRootNavigator: false,
      );
    } on DioException catch (e) {
      final msg = (e.response?.data is Map && (e.response!.data['error']?['message'] is String))
          ? e.response!.data['error']['message'] as String
          : 'Falha ao gravar autorização';

      if (!mounted) return;
      final isBusiness = (e.response?.data is Map) &&
          ((e.response!.data['error']?['code'] ?? '') == 'BUSINESS_RULE');
      await AppAlert.show(
        context,
        title: isBusiness ? 'Atenção' : 'Erro',
        message: msg,
        type: isBusiness ? AppAlertType.warning : AppAlertType.error,
        useRootNavigator: false,
      );
    } catch (e) {
      if (!mounted) return;
      await AppAlert.show(
        context,
        title: 'Erro',
        message: e.toString(),
        type: AppAlertType.error,
        useRootNavigator: false,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Abre a tela de preview/impressão a partir do número recém-emitido
  Future<void> _openPreviewFromNumero(int numero) async {
    try {
      final profile = await Session.getProfile();
      if (profile == null) {
        if (!mounted) return;
        AppAlert.toast(context, 'Não foi possível obter o perfil do usuário.');
        return;
      }

      final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
          ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');

      final reimpRepo = ReimpressaoRepository(DevApi(baseUrl));
      final det = await reimpRepo.detalhe(numero, idMatricula: profile.id);
      if (det == null) {
        if (!mounted) return;
        AppAlert.toast(context, 'Não foi possível carregar os detalhes desta ordem.');
        return;
      }

      final AutorizacaoPdfData data = mapDetalheToPdfData(
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
      AppAlert.toast(context, 'Falha ao abrir impressão: $e');
    }
  }

  // volta para HomeServicos dentro da aba (mantém hotbar)
  void _goBackToServicos() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  // ===== Card do prestador (aparece só quando há seleção) =====
  Widget _prestadorCardOrEmpty() {
    final p = _selPrest;
    if (p == null) return const SizedBox.shrink();

    String up(String? s) => (s ?? '').trim().toUpperCase();
    final vinc = up((p.vinculoNome != null && p.vinculoNome!.trim().isNotEmpty) ? p.vinculoNome : p.vinculo);
    final l1 = up(p.endereco);
    final cidadeUf = [up(p.cidade), up(p.uf)].where((e) => e.isNotEmpty).join('/');
    final l2 = [up(p.bairro), cidadeUf].where((e) => e.isNotEmpty).join(' - ');

    return Column(
      children: [
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE6E9EF)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Text(up(p.nome), textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                if (vinc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(vinc, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                ],
                if (l1.isNotEmpty || l2.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (l1.isNotEmpty) Text(l1, textAlign: TextAlign.center),
                  if (l2.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(l2, textAlign: TextAlign.center),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Autorização Médica',
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16,16,16,24),
          children: [
            if (_loading) const SectionCard(title: ' ', child: LoadingPlaceholder(height: 120)),
            if (!_loading && _error != null)
              SectionCard(
                title: ' ',
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ),

            if (!_loading && _error == null) ...[
              SectionCard(
                title: 'Paciente',
                child: DropdownButtonFormField<_Beneficiario>(
                  isExpanded: true,
                  value: _selBenef,
                  items: _beneficiarios.map((b){
                    final isTit = b.idDep==0;
                    return DropdownMenuItem(value: b, child: Text(isTit ? '${b.nome} (Titular)' : b.nome));
                  }).toList(),
                  onChanged: (v)=>setState(()=>_selBenef=v),
                  decoration: _inputDeco('Selecione o Paciente'),
                ),
              ),
              const SizedBox(height: 12),

              SectionCard(
                title: 'Especialidade',
                child: DropdownButtonFormField<Especialidade>(
                  isExpanded: true,
                  value: _selEsp,
                  items: _especialidades.map((e)=>DropdownMenuItem(value: e, child: Text(e.nome))).toList(),
                  onChanged: (v){
                    setState(() {
                      _selEsp = v;
                      _cidades = const [];
                      _selCidade = null;
                      _prestadores = const [];
                      _selPrest = null;
                    });
                    if (v!=null) _loadCidades();
                  },
                  decoration: _inputDeco('Escolha a especialidade'),
                ),
              ),
              const SizedBox(height: 12),

              SectionCard(
                title: 'Cidade',
                child: Column(
                  children: [
                    if (_loadingCidades) const LoadingPlaceholder(height: 60),
                    if (!_loadingCidades)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selCidade,
                        items: _cidades.map((c)=>DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (_selEsp==null)?null:(v){
                          setState(() { _selCidade = v; _prestadores = const []; _selPrest = null; });
                          if (v!=null) _loadPrestadores();
                        },
                        decoration: _inputDeco(
                          _selEsp==null
                              ? 'Escolha a especialidade primeiro'
                              : (_cidades.isEmpty ? 'Sem cidades disponíveis' : 'Selecione a cidade'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              SectionCard(
                title: 'Prestador',
                child: Column(
                  children: [
                    if (_loadingPrestadores) const LoadingPlaceholder(height: 60),
                    if (!_loadingPrestadores)
                      DropdownButtonFormField<PrestadorRow>(
                        isExpanded: true,
                        value: _selPrest,
                        items: _prestadores.map((p)=>DropdownMenuItem(
                          value: p,
                          child: Text(p.nome),
                        )).toList(),
                        onChanged: (_selCidade==null)?null:(v)=>setState(()=>_selPrest=v),
                        decoration: _inputDeco(
                          _selCidade==null
                              ? 'Selecione a cidade primeiro'
                              : (_prestadores.isEmpty ? 'Sem prestadores para o filtro' : 'Escolha o prestador'),
                        ),
                      ),

                    // 👉 Card de detalhes do prestador (somente se selecionado)
                    _prestadorCardOrEmpty(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kBrand,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _formOk && !_saving ? _onSubmit : null,
                  child: _saving
                      ? const SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                      : const Text('Continuar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBrand, width: 1.6)),
  );
}

class _Beneficiario {
  final int idMat; final int idDep; final String nome;
  const _Beneficiario({required this.idMat, required this.idDep, required this.nome});
}
extension<T> on List<T> { T? get firstOrNull => isEmpty ? null : first; }
