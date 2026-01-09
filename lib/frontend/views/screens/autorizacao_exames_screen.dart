import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../theme/colors.dart';
import '../components/app_alert.dart';
import '../components/dropdown_utils.dart';
import '../components/loading_placeholder.dart';
import '../components/cards/section_card.dart';
import '../layouts/app_shell.dart';
import '../components/section_inset.dart';
import 'exames/widgets/orientacoes_body.dart';
import 'exames/widgets/prestador_detail_card.dart';
import 'exames/widgets/thumb_grid.dart'; // buildMenuItems/buildSelecteds

class AutorizacaoExamesScreen extends StatefulWidget {
  const AutorizacaoExamesScreen({super.key});

  @override
  State<AutorizacaoExamesScreen> createState() =>
      _AutorizacaoExamesScreenState();
}

class _AutorizacaoExamesScreenState extends State<AutorizacaoExamesScreen> {
  static const String _version = 'AutorizacaoExamesScreen v1.5.0';

  final ImagePicker _picker = ImagePicker();
  List<XFile> _imagens = [];

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
        List<Dependent> rows = const [];
        try {
          rows = await _depsRepo.listByMatricula(profile.id);
        } catch (_) {}

        // === REGRA DE CONTEXTO (igual Médica/Odonto) =====================
        //
        // Se dentro dessa matrícula existir um dependente (iddependente != 0)
        // com CPF igual ao CPF do profile → login de DEPENDENTE.
        // Nesse caso mostramos apenas esse beneficiário.
        //
        // Caso contrário, login de TITULAR → inclui titular (se não vier)
        // e mantém todos os dependentes.
        final cpfPerfilDigits =
        profile.cpf.replaceAll(RegExp(r'\D'), '');

        Dependent? selfDep;
        for (final d in rows) {
          final dc = d.cpf;
          if (dc == null || dc.isEmpty) continue;
          final dcDigits = dc.replaceAll(RegExp(r'\D'), '');
          if (d.iddependente != 0 && dcDigits == cpfPerfilDigits) {
            selfDep = d;
            break;
          }
        }

        if (selfDep != null) {
          // Login de dependente: somente ele
          rows = [selfDep];
        } else {
          // Login de titular: garante linha do titular e mantém dependentes
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
        // =================================================================

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
        _especialidades = await _espRepo.listarExames();
      } catch (e) {
        if (kDebugMode) print('especialidades (exames) erro: $e');
        _especialidades = const [];
      }

      _selEsp = null;
      _cidades = const [];
      _selCidade = null;
      _prestadores = const [];
      _selPrest = null;
      _imagens = [];
    } catch (e) {
      _error = kDebugMode
          ? 'Falha ao carregar dados. ($e)'
          : 'Falha ao carregar dados.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addImages() async {
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (picked.isEmpty) return;

      // junta com o que já tem e limita a 2 imagens
      final merged = [..._imagens, ...picked].take(2).toList();

      // valida 10 MB por imagem
      for (final x in merged) {
        final bytes = await x.length();
        if (bytes > 10 * 1024 * 1024) {
          AppAlert.toast(context, 'Cada imagem deve ter até 10 MB.');
          return;
        }
      }

      setState(() => _imagens = merged);
    } catch (e) {
      if (kDebugMode) print('addImages error: $e');
      AppAlert.toast(context, 'Falha ao adicionar imagens.');
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
      final rows =
      await _prestRepo.porEspecialidade(_selEsp!.id, cidade: cidade);
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
          _selPrest != null &&
          _imagens.isNotEmpty;

  Future<void> _onSubmit() async {
    if (!_formOk || _saving) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final numero = await _autRepo.gravarExame(
        idMatricula: _selBenef!.idMat,
        idDependente: _selBenef!.idDep,
        idPrestador: _toInt(_selPrest!.registro),
        tipoPrestador: _selPrest!.tipoPrestador,
      );

      try {
        await _autRepo.enviarImagensExame(
          numero: numero,
          files: _imagens,
        );
      } catch (e) {
        await AppAlert.show(
          context,
          title: 'Falha no envio das imagens',
          message:
          'A autorização nº $numero foi gerada, mas não conseguimos anexar as fotos. Tente reenviar agora.',
          type: AppAlertType.error,
          useRootNavigator: false,
        );
        return;
      }

      AuthEvents.instance.emitIssued(numero);

      setState(() {
        _selEsp = null;
        _selCidade = null;
        _selPrest = null;
        _cidades = const [];
        _prestadores = const [];
        _imagens = [];
      });

      if (!mounted) return;

      await AppAlert.showAuthNumber(
        context,
        numero: numero,
        useRootNavigator: false,
        pendente: true,
        pendenteMsg:
        'Autorização enviada para análise.\nPrevisão de até 48h.',
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

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Autorização de Exames',
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
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Falha ao carregar.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            if (!_loading && _error == null) ...[
              const SectionCard(
                title: 'Orientações',
                child: SectionInset(child: OrientacoesBody()),
              ),
              const SizedBox(height: 12),

              SectionCard(
                title: 'Requisição (fotos) — obrigatório',
                child: SectionInset(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.tonal(
                            onPressed:
                            _imagens.length >= 2 ? null : _addImages,
                            child:
                            const Text('Adicionar imagens (até 2)'),
                          ),
                          FilledButton.tonal(
                            onPressed:
                            _imagens.length >= 2 ? null : _capturePhoto,
                            child: const Text('Câmera'),
                          ),
                          Text(
                            '${_imagens.length}/2 selecionadas',
                            style:
                            const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ThumbGrid(
                        images: _imagens,
                        onRemove: (i) => setState(
                              () =>
                          _imagens = [..._imagens]..removeAt(i),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SectionCard(
                title: 'Paciente',
                child: DropdownButtonFormField<_Beneficiario>(
                  isExpanded: true,
                  value: _selBenef,
                  items: buildMenuItems<_Beneficiario>(
                    data: _beneficiarios,
                    labelOf: (b) =>
                    b.idDep == 0 ? '${b.nome} (Titular)' : b.nome,
                  ),
                  selectedItemBuilder: (_) =>
                      buildSelecteds<_Beneficiario>(
                        data: _beneficiarios,
                        labelOf: (b) =>
                        b.idDep == 0 ? '${b.nome} (Titular)' : b.nome,
                      ),
                  onChanged: (v) => setState(() => _selBenef = v),
                  decoration: _inputDeco('Selecione o Paciente'),
                ),
              ),
              const SizedBox(height: 12),

              SectionCard(
                title: 'Especialidade',
                child: DropdownButtonFormField<Especialidade>(
                  isExpanded: true,
                  value: _selEsp,
                  items: buildMenuItems<Especialidade>(
                    data: _especialidades,
                    labelOf: (e) => e.nome,
                  ),
                  selectedItemBuilder: (_) =>
                      buildSelecteds<Especialidade>(
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
                  decoration:
                  _inputDeco('Escolha a especialidade (Exames)'),
                ),
              ),
              const SizedBox(height: 12),

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
                        items: buildMenuItems<String>(
                          data: _cidades,
                          labelOf: (c) => c,
                        ),
                        selectedItemBuilder: (_) =>
                            buildSelecteds<String>(
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
                        items: buildMenuItems<PrestadorRow>(
                          data: _prestadores,
                          labelOf: (p) => p.nome,
                        ),
                        selectedItemBuilder: (_) =>
                            buildSelecteds<PrestadorRow>(
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
                    PrestadorDetailCard(prestador: _selPrest),
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

  Future<void> _capturePhoto() async {
    try {
      if (_imagens.length >= 2) return;

      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (shot == null) return;

      final size = await shot.length();
      if (size > 10 * 1024 * 1024) {
        if (!mounted) return;
        AppAlert.toast(context, 'A foto deve ter até 10 MB.');
        return;
      }

      setState(() {
        _imagens =
            [..._imagens, shot].take(2).toList();
      });
    } catch (_) {
      if (!mounted) return;
      AppAlert.toast(context, 'Falha ao abrir a câmera.');
    }
  }
}

// Modelo simples só para esta tela
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
