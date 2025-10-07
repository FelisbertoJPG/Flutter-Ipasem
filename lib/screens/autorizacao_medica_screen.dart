// lib/screens/autorizacao_medica_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../ui/app_shell.dart';
import '../ui/components/section_card.dart';
import '../ui/components/loading_placeholder.dart';

import '../config/app_config.dart';
import '../services/dev_api.dart';
import '../repositories/dependents_repository.dart';
import '../repositories/especialidades_repository.dart';
import '../repositories/prestadores_repository.dart';
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
  bool _loading = true;
  String? _error;

  bool _loadingCidades = false;
  bool _loadingPrestadores = false;

  // ---- Seleções ----
  _Beneficiario? _selBenef;
  Especialidade? _selEsp;
  String? _selCidade;
  PrestadorRow? _selPrest;

  // ---- Dados ----
  List<_Beneficiario> _beneficiarios = const [];
  List<Especialidade> _especialidades = const [];
  List<String> _cidades = const [];
  List<PrestadorRow> _prestadores = const [];

  // ---- Repos/API ----
  bool _reposReady = false;
  late DevApi _api;
  late DependentsRepository _depsRepo;
  late EspecialidadesRepository _espRepo;
  late PrestadoresRepository _prestRepo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reposReady) return;

    final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
        ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');

    _api = DevApi(baseUrl);
    _depsRepo = DependentsRepository(_api);
    _espRepo  = EspecialidadesRepository(_api);
    _prestRepo = PrestadoresRepository(_api);

    _reposReady = true;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() { _loading = true; _error = null; });

    try {
      // 1) Beneficiário (titular + dependentes)
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
          ..sort((a,b){
            if (a.idDep==0 && b.idDep!=0) return -1;
            if (a.idDep!=0 && b.idDep==0) return 1;
            return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
          });
        _selBenef = _beneficiarios.firstOrNull;
      }

      // 2) Especialidades reais
      try {
        _especialidades = await _espRepo.listar();
      } catch (e) {
        if (kDebugMode) print('especialidades erro: $e');
        _especialidades = const [];
      }

      // limpa filtros dependentes
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
    setState(() { _loadingCidades = true; _cidades = const []; _selCidade = null; _prestadores = const []; _selPrest = null; });
    try {
      final rows = await _prestRepo.cidadesDisponiveis(_selEsp!.id);
      setState(() {
        _cidades = rows;
        _loadingCidades = false;
      });
    } catch (e) {
      setState(() { _loadingCidades = false; _cidades = const []; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kDebugMode ? 'Falha ao carregar cidades. ($e)' : 'Falha ao carregar cidades.')),
      );
    }
  }

  Future<void> _loadPrestadores() async {
    if (_selEsp == null) return;
    setState(() { _loadingPrestadores = true; _prestadores = const []; _selPrest = null; });
    try {
      final cidade = (_selCidade == null || _selCidade == 'TODAS AS CIDADES') ? null : _selCidade;
      final rows = await _prestRepo.porEspecialidade(_selEsp!.id, cidade: cidade);
      setState(() {
        _prestadores = rows;
        _loadingPrestadores = false;
      });
    } catch (e) {
      setState(() { _loadingPrestadores = false; _prestadores = const []; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kDebugMode ? 'Falha ao carregar prestadores. ($e)' : 'Falha ao carregar prestadores.')),
      );
    }
  }

  bool get _formOk => _selBenef != null && _selEsp != null && _selCidade != null && _selPrest != null;

  void _onSubmit() {
    if (!_formOk) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'OK!\nPaciente: ${_selBenef!.nome}\n'
            'Especialidade: ${_selEsp!.nome}\n'
            'Cidade: ${_selCidade!}\n'
            'Prestador: ${_selPrest!.nome}\n'
            '(gravação virá via repo)',
      ),
    ));
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
              SectionCard(title: ' ', child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red)))),

            if (!_loading && _error == null) ...[
              // Paciente
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

              // Especialidade
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

              // Cidade
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

              // Prestador
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
                  onPressed: _formOk ? _onSubmit : null,
                  child: const Text('Continuar', style: TextStyle(fontWeight: FontWeight.w700)),
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

// Tipos internos simples
class _Beneficiario {
  final int idMat; final int idDep; final String nome;
  const _Beneficiario({required this.idMat, required this.idDep, required this.nome});
}
extension<T> on List<T> { T? get firstOrNull => isEmpty ? null : first; }
