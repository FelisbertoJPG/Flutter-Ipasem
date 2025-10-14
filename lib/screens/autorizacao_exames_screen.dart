// lib/screens/autorizacao_exames_screen.dart
import 'dart:io';

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../state/auth_events.dart';
import '../ui/utils/print_helpers.dart'; // openPreviewFromNumero

import '../theme/colors.dart';
import '../ui/app_shell.dart';
import '../ui/components/section_card.dart';
import '../ui/components/loading_placeholder.dart';
import '../ui/components/app_alert.dart';

import '../config/app_config.dart';
import '../services/dev_api.dart';
import '../services/session.dart';

import '../repositories/dependents_repository.dart';
import '../repositories/autorizacoes_repository.dart';
import '../repositories/especialidades_repository.dart';
import '../repositories/prestadores_repository.dart';

import '../models/dependent.dart';
import '../models/especialidade.dart';
import '../models/prestador.dart';

class AutorizacaoExamesScreen extends StatefulWidget {
  const AutorizacaoExamesScreen({super.key});

  @override
  State<AutorizacaoExamesScreen> createState() => _AutorizacaoExamesScreenState();
}

class _AutorizacaoExamesScreenState extends State<AutorizacaoExamesScreen> {
  static const String _version = 'AutorizacaoExamesScreen v1.4.0';

  // anexos
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
  late EspecialidadesRepository _espRepo; // listarExames()
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

  // exige anexos
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
      // 1) gravação específica de exames
      final numero = await _autRepo.gravarExame(
        idMatricula:   _selBenef!.idMat,
        idDependente:  _selBenef!.idDep,
        idPrestador:   _toInt(_selPrest!.registro),
        tipoPrestador: _selPrest!.tipoPrestador,
      );

      // 2) sobe as fotos (obrigatório)
      try {
        await _autRepo.enviarImagensExame(
          numero: numero,
          files: _imagens, // <-- passe a lista de XFile direto
        );
      } catch (e) {
        await AppAlert.show(
          context,
          title: 'Falha no envio das imagens',
          message: 'A autorização nº $numero foi gerada, mas não conseguimos anexar as fotos. Tente reenviar agora.',
          type: AppAlertType.error,
          useRootNavigator: false,
        );
        return;
      }



      // 3) notifica HomeServicos para auto-atualizar
      AuthEvents.instance.emitIssued(numero);

      // 4) limpa seleção somente após upload OK
      setState(() {
        _selEsp = null;
        _selCidade = null;
        _selPrest = null;
        _cidades = const [];
        _prestadores = const [];
        _imagens = [];
      });

      if (!mounted) return;

      // 5) Dialog com número + “Abrir impressão”
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

  void _goBackToServicos({int? numero}) {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop({'issued': true, 'numero': numero});
    }
  }



  // ====== anexos helpers ======
Future<void> _addImages() async {
  try {
    final picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2000);
    if (picked.isEmpty) return;

    // junta com o que já tem e corta no máximo 2
    final merged = [..._imagens, ...picked].take(2).toList();

    // validação 10MB por imagem — use XFile.length() (cross-platform)
    for (final x in merged) {
      final bytes = await x.length(); // <-- em vez de File(x.path).length()
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

  void _removeImage(int index) {
    setState(() => _imagens = [..._imagens]..removeAt(index));
  }

  // ====== UI ======

  // grid de miniaturas responsivo
  Widget _thumbGrid() {
    if (_imagens.isEmpty) return const Text('Anexe ao menos 1 imagem da requisição.');
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        int cols;
        if (w >= 520) {
          cols = 5;
        } else if (w >= 420) {
          cols = 4;
        } else if (w >= 340) {
          cols = 3;
        } else {
          cols = 2;
        }
        const gap = 8.0;
        final thumb = ((w - (gap * (cols - 1))) / cols).clamp(72.0, 112.0);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(_imagens.length, (i) {
            final x = _imagens[i];

            Widget img;
            if (kIsWeb) {
              // No Web, leia os bytes
              img = FutureBuilder<Uint8List>(
                future: x.readAsBytes(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  return Image.memory(snap.data!, fit: BoxFit.cover);
                },
              );
            } else {
              // Em mobile/desktop, pode usar Image.file normalmente
              img = Image.file(File(x.path), fit: BoxFit.cover);
            }

            return SizedBox(
              width: thumb,
              height: thumb,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: img,
                    ),
                  ),
                  Positioned(
                    right: -8,
                    top: -8,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.cancel, size: 20),
                      onPressed: () => _removeImage(i),
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }


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
      title: 'Autorização de Exames',
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
              // Orientações
              SectionCard(
                title: 'Orientações',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _Bullet('A imagem da requisição deve ser completa e sem cortes.'),
                    _Bullet('Se houver exames para locais diferentes, emita autorizações separadas.'),
                    _Bullet('Tamanho máximo da imagem 10MB (quando aplicável).'),
                    _Bullet('Após a solicitação, o retorno pode levar até 48 horas.'),
                    _Bullet('Você pode consultar suas solicitações no histórico do app.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Anexos (obrigatório)
              SectionCard(
                title: 'Requisição (fotos) — obrigatório',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wrap evita overflow em telas estreitas
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.tonal(
                          onPressed: _imagens.length >= 2 ? null : _addImages,
                          child: const Text('Adicionar imagens (até 2)', overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          '${_imagens.length}/2 selecionadas',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _thumbGrid(),
                  ],
                ),
              ),
              const SizedBox(height: 12),

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
                  decoration: _inputDeco('Escolha a especialidade (Exames)'),
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
                    _prestadorCardOrEmpty(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Submit
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

// Tipos internos
class _Beneficiario {
  final int idMat; final int idDep; final String nome;
  const _Beneficiario({required this.idMat, required this.idDep, required this.nome});
}
extension<T> on List<T> { T? get firstOrNull => isEmpty ? null : first; }

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(height: 1.4)),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
