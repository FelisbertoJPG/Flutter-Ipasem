// lib/frontend/views/screens/autorizacao_medica_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../common/config/app_config.dart';
import '../../../common/models/dependent.dart';
import '../../../common/models/especialidade.dart';
import '../../../common/models/prestador.dart';
import '../../../common/repositories/autorizacoes_repository.dart';
import '../../../common/repositories/dependents_repository.dart';
import '../../../common/repositories/especialidades_repository.dart';
import '../../../common/repositories/prestadores_repository.dart';
import '../../../common/config/dev_api.dart';
import '../../../common/services/session.dart';
import '../../../common/state/auth_events.dart';
import '../components/app_alert.dart';
import '../components/loading_placeholder.dart';
import '../components/cards/section_card.dart';
import '../layouts/menu_shell.dart';
import '../../theme/colors.dart';
import '../ui/utils/print_helpers.dart';

class AutorizacaoMedicaScreen extends StatefulWidget {
  const AutorizacaoMedicaScreen({super.key});

  @override
  State<AutorizacaoMedicaScreen> createState() =>
      _AutorizacaoMedicaScreenState();
}

class _AutorizacaoMedicaScreenState extends State<AutorizacaoMedicaScreen> {
  static const String _version = 'AutorizacaoMedicaScreen v1.3.8';

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

    final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl ??
        const String.fromEnvironment(
          'API_BASE',
          defaultValue: 'http://192.9.200.98',
        );

    _api = DevApi(baseUrl);
    _depsRepo = DependentsRepository(_api);
    _espRepo = EspecialidadesRepository(_api);
    _prestRepo = PrestadoresRepository(_api);
    _autRepo = AutorizacoesRepository(_api);

    _reposReady = true;
    if (kDebugMode) debugPrint(_version);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await Session.getProfile();
      if (profile == null) {
        _error = 'Faça login para solicitar autorização.';
      } else {
        // Carrega todos os beneficiários da matrícula escolhida
        List<Dependent> rows = const [];
        try {
          rows = await _depsRepo.listByMatricula(profile.id);
        } catch (_) {}

        // === REGRA DE CONTEXTO (nova) ======================================
        //
        // Se dentro dessa matrícula existir um dependente (iddependente != 0)
        // com CPF igual ao CPF do profile, tratamos como LOGIN DE DEPENDENTE
        // e mostramos apenas esse beneficiário.
        //
        // Caso contrário, é login de titular → mostramos titular + todos
        // os dependentes (completando o titular caso o backend não mande).
        final cpfPerfilDigits =
        profile.cpf.replaceAll(RegExp(r'\D'), '');

        Dependent? selfDep;
        for (final d in rows) {
          final dc = d.cpf;
          if (dc == null || dc.isEmpty) continue;
          final dcDigits = dc.replaceAll(RegExp(r'\D'), '');
          // titular tem iddependente == 0; dependente é != 0 (positivo ou negativo)
          if (d.iddependente != 0 && dcDigits == cpfPerfilDigits) {
            selfDep = d;
            break;
          }
        }

        if (selfDep != null) {
          // Login de dependente: apenas ele no combo "Paciente".
          rows = [selfDep];
        } else {
          // Login de titular: mantém comportamento anterior.
          final hasTitular = rows.any((d) => d.iddependente == 0);
          if (!hasTitular) {
            rows = [
              Dependent(
                nome: profile.nome,
                idmatricula: profile.id,
                iddependente: 0,
                cpf: profile.cpf,
                sexo: profile.sexoTxt ?? profile.sexo,
              ),
              ...rows,
            ];
          }
        }
        // ===================================================================

        _beneficiarios = rows
            .map(
              (d) => _Beneficiario(
            idMat: d.idmatricula,
            idDep: d.iddependente,
            nome: d.nome,
          ),
        )
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
        if (kDebugMode) debugPrint('especialidades erro: $e');
        _especialidades = const [];
      }

      _selEsp = null;
      _cidades = const [];
      _selCidade = null;
      _prestadores = const [];
      _selPrest = null;
    } catch (e) {
      _error = kDebugMode
          ? 'Falha ao carregar dados. ($e)'
          : 'Falha ao carregar dados.';
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
      setState(() {
        _loadingCidades = false;
        _cidades = const [];
      });
      if (!mounted) return;
      AppAlert.toast(
        context,
        kDebugMode
            ? 'Falha ao carregar cidades. ($e)'
            : 'Falha ao carregar cidades.',
      );
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
      final cidade = (_selCidade == null || _selCidade == 'TODAS AS CIDADES')
          ? null
          : _selCidade;
      final rows = await _prestRepo.porEspecialidade(
        _selEsp!.id,
        cidade: cidade,
      );
      setState(() {
        _prestadores = rows;
        _loadingPrestadores = false;
      });
    } catch (e) {
      setState(() {
        _loadingPrestadores = false;
        _prestadores = const [];
      });
      AppAlert.toast(
        context,
        kDebugMode
            ? 'Falha ao carregar prestadores. ($e)'
            : 'Falha ao carregar prestadores.',
      );
    }
  }

  bool get _formOk =>
      _selBenef != null &&
          _selEsp != null &&
          _selCidade != null &&
          _selPrest != null;

  Future<void> _onSubmit() async {
    if (!_formOk || _saving) return;

    setState(() => _saving = true);
    try {
      final numero = await _autRepo.gravar(
        idMatricula: _selBenef!.idMat,
        idDependente: _selBenef!.idDep,
        idEspecialidade: _toInt(_selEsp!.id),
        idPrestador: _toInt(_selPrest!.registro),
        tipoPrestador: _selPrest!.tipoPrestador,
      );

      // evento para HomeServicos
      AuthEvents.instance.emitIssued(numero);

      // limpa seleção
      setState(() {
        _selEsp = null;
        _selCidade = null;
        _selPrest = null;
        _cidades = const [];
        _prestadores = const [];
      });

      if (!mounted) return;

      await AppAlert.showAuthNumber(
        context,
        numero: numero,
        useRootNavigator: false,
        onOpenPreview: () => openPreviewFromNumero(context, numero),
        onOk: () => _goBackToServicos(numero: numero),
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
      final msg = (e.response?.data is Map &&
          (e.response!.data['error']?['message'] is String))
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

  void _goBackToServicos({int? numero}) {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop({'issued': true, 'numero': numero});
    }
  }

  // === Helpers para itens com divisor (menu) e exibição limpa (campo) ===
  static const _kMenuDivider =
  BorderSide(color: Color(0xFFE6E9EF), width: 0.8);

  List<DropdownMenuItem<T>> _buildMenuItems<T>({
    required List<T> data,
    required String Function(T) labelOf,
  }) {
    final out = <DropdownMenuItem<T>>[];
    for (var i = 0; i < data.length; i++) {
      final e = data[i];
      final isLast = i == data.length - 1;
      out.add(
        DropdownMenuItem<T>(
          value: e,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: _kMenuDivider),
            ),
            child: Text(
              labelOf(e),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    return out;
  }

  List<Widget> _buildSelecteds<T>({
    required List<T> data,
    required String Function(T) labelOf,
  }) {
    // usado no campo fechado (sem “linha”)
    return data
        .map(
          (e) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          labelOf(e),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    )
        .toList();
  }

  // ===== Card do prestador (aparece só quando há seleção) =====
  Widget _prestadorCardOrEmpty() {
    final p = _selPrest;
    if (p == null) return const SizedBox.shrink();

    String up(String? s) => (s ?? '').trim().toUpperCase();
    final vinc = up(
      (p.vinculoNome != null && p.vinculoNome!.trim().isNotEmpty)
          ? p.vinculoNome
          : p.vinculo,
    );
    final l1 = up(p.endereco);
    final cidadeUf =
    [up(p.cidade), up(p.uf)].where((e) => e.isNotEmpty).join('/');
    final l2 = [up(p.bairro), cidadeUf]
        .where((e) => e.isNotEmpty)
        .join(' - ');

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
                Text(
                  up(p.nome),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (vinc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    vinc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
                if (l1.isNotEmpty || l2.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (l1.isNotEmpty)
                    Text(l1, textAlign: TextAlign.center),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (_loading)
              const SectionCard(
                title: ' ',
                child: LoadingPlaceholder(height: 120),
              ),
            if (!_loading && _error != null)
              SectionCard(
                title: ' ',
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            if (!_loading && _error == null) ...[
              // ===== Paciente
              SectionCard(
                title: 'Paciente',
                child: DropdownButtonFormField<_Beneficiario>(
                  isExpanded: true,
                  value: _selBenef,
                  items: _buildMenuItems<_Beneficiario>(
                    data: _beneficiarios,
                    labelOf: (b) =>
                    b.idDep == 0 ? '${b.nome} (Titular)' : b.nome,
                  ),
                  selectedItemBuilder: (_) =>
                      _buildSelecteds<_Beneficiario>(
                        data: _beneficiarios,
                        labelOf: (b) =>
                        b.idDep == 0 ? '${b.nome} (Titular)' : b.nome,
                      ),
                  onChanged: (v) => setState(() => _selBenef = v),
                  decoration: _inputDeco('Selecione o Paciente'),
                ),
              ),
              const SizedBox(height: 12),

              // ===== Especialidade
              SectionCard(
                title: 'Especialidade',
                child: DropdownButtonFormField<Especialidade>(
                  isExpanded: true,
                  value: _selEsp,
                  items: _buildMenuItems<Especialidade>(
                    data: _especialidades,
                    labelOf: (e) => e.nome,
                  ),
                  selectedItemBuilder: (_) =>
                      _buildSelecteds<Especialidade>(
                        data: _especialidades,
                        labelOf: (e) => e.nome,
                      ),
                  onChanged: (v) {
                    setState(() {
                      _selEsp = v;
                      _cidades = const [];
                      _selCidade = null;
                      _prestadores = const [];
                      _selPrest = null;
                    });
                    if (v != null) _loadCidades();
                  },
                  decoration: _inputDeco('Escolha a especialidade'),
                ),
              ),
              const SizedBox(height: 12),

              // ===== Cidade
              SectionCard(
                title: 'Cidade',
                child: Column(
                  children: [
                    if (_loadingCidades)
                      const LoadingPlaceholder(height: 60),
                    if (!_loadingCidades)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selCidade,
                        items: _buildMenuItems<String>(
                          data: _cidades,
                          labelOf: (c) => c,
                        ),
                        selectedItemBuilder: (_) =>
                            _buildSelecteds<String>(
                              data: _cidades,
                              labelOf: (c) => c,
                            ),
                        onChanged: (_selEsp == null)
                            ? null
                            : (v) {
                          setState(() {
                            _selCidade = v;
                            _prestadores = const [];
                            _selPrest = null;
                          });
                          if (v != null) _loadPrestadores();
                        },
                        decoration: _inputDeco(
                          _selEsp == null
                              ? 'Escolha a especialidade primeiro'
                              : (_cidades.isEmpty
                              ? 'Sem cidades disponíveis'
                              : 'Selecione a cidade'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ===== Prestador
              SectionCard(
                title: 'Prestador',
                child: Column(
                  children: [
                    if (_loadingPrestadores)
                      const LoadingPlaceholder(height: 60),
                    if (!_loadingPrestadores)
                      DropdownButtonFormField<PrestadorRow>(
                        isExpanded: true,
                        value: _selPrest,
                        items: _buildMenuItems<PrestadorRow>(
                          data: _prestadores,
                          labelOf: (p) => p.nome,
                        ),
                        selectedItemBuilder: (_) =>
                            _buildSelecteds<PrestadorRow>(
                              data: _prestadores,
                              labelOf: (p) => p.nome,
                            ),
                        onChanged: (_selCidade == null)
                            ? null
                            : (v) =>
                            setState(() => _selPrest = v),
                        decoration: _inputDeco(
                          _selCidade == null
                              ? 'Selecione a cidade primeiro'
                              : (_prestadores.isEmpty
                              ? 'Sem prestadores para o filtro'
                              : 'Escolha o prestador'),
                        ),
                      ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _formOk && !_saving ? _onSubmit : null,
                  child: _saving
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : const Text(
                    'Continuar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
      const BorderSide(color: kBrand, width: 1.6),
    ),
  );
}

class _Beneficiario {
  final int idMat;
  final int idDep;
  final String nome;
  const _Beneficiario({
    required this.idMat,
    required this.idDep,
    required this.nome,
  });
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
