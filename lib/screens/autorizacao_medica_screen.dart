// lib/screens/autorizacao_medica_screen.dart
import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../ui/app_shell.dart';
import '../ui/components/section_card.dart';
import '../ui/components/loading_placeholder.dart';

import '../config/app_config.dart';
import '../services/dev_api.dart';
import '../repositories/dependents_repository.dart';
import '../services/session.dart';
import '../models/dependent.dart';

class AutorizacaoMedicaScreen extends StatefulWidget {
  const AutorizacaoMedicaScreen({super.key});

  @override
  State<AutorizacaoMedicaScreen> createState() => _AutorizacaoMedicaScreenState();
}

class _AutorizacaoMedicaScreenState extends State<AutorizacaoMedicaScreen> {
  bool _loading = true;
  String? _error;

  // ---- Seleções ----
  _Beneficiario? _selBenef; // titular/dependente
  _Item? _selEsp;
  _Item? _selCidade;
  _Prestador? _selPrest;

  // ---- Dados ----
  List<_Beneficiario> _beneficiarios = const [];
  List<_Item> _especialidades = const [];
  List<_Item> _cidades = const [];
  List<_Prestador> _prestadores = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ===== 1) Carrega titular/dependentes do SP via repository =====
      final profile = await Session.getProfile();
      if (profile == null) {
        _error = 'Faça login para solicitar autorização.';
      } else {
        final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
            ?? const String.fromEnvironment(
              'API_BASE',
              defaultValue: 'https://assistweb.ipasemnh.com.br',
            );

        final depsRepo = DependentsRepository(DevApi(baseUrl));
        List<Dependent> rows = const [];
        try {
          rows = await depsRepo.listByMatricula(profile.id);
        } catch (_) {
          rows = const [];
        }

        // Garante presença do TITULAR (iddependente == 0)
        final hasTitular = rows.any((d) => d.iddependente == 0);
        if (!hasTitular) {
          rows = [
            Dependent(
              nome: profile.nome,
              idmatricula: profile.id,
              iddependente: 0,
              cpf: profile.cpf,
            ),
            ...rows,
          ];
        }

        // Mapeia para a estrutura de beneficiário da tela
        _beneficiarios = rows
            .map((d) => _Beneficiario(idMat: d.idmatricula, idDep: d.iddependente, nome: d.nome))
            .toList()
          ..sort((a, b) {
            // Titular primeiro; depois por nome
            if (a.idDep == 0 && b.idDep != 0) return -1;
            if (a.idDep != 0 && b.idDep == 0) return 1;
            return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
          });

        _selBenef = _beneficiarios.firstOrNull;
      }

      // ===== 2) Demais listas (mock por enquanto; trocar por repos) =====
      _especialidades = const [
        _Item(10, 'Clínico Geral'),
        _Item(20, 'Pediatria'),
        _Item(30, 'Ortopedia'),
        _Item(40, 'Cardiologia'),
      ];

      _cidades = const [
        _Item(500, 'Novo Hamburgo'),
        _Item(501, 'São Leopoldo'),
        _Item(502, 'Campo Bom'),
      ];

      _prestadores = const [
        _Prestador(9000, 'Clínica Vida', idCidade: 500, especialidades: [10, 30]),
        _Prestador(9001, 'Hospital Coração', idCidade: 500, especialidades: [40, 10]),
        _Prestador(9002, 'Clínica Sorrisos', idCidade: 501, especialidades: [20]),
        _Prestador(9003, 'Orto Center', idCidade: 502, especialidades: [30]),
      ];
    } catch (_) {
      _error = 'Falha ao carregar dados.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Prestador> get _prestadoresFiltrados {
    if (_selCidade == null) return const [];
    final cid = _selCidade!.id;
    final esp = _selEsp?.id;
    return _prestadores.where((p) {
      final okCidade = p.idCidade == cid;
      final okEsp = esp == null ? true : p.especialidades.contains(esp);
      return okCidade && okEsp;
    }).toList();
  }

  bool get _formOk =>
      _selBenef != null && _selEsp != null && _selCidade != null && _selPrest != null;

  void _onSubmit() {
    if (!_formOk) return;
    // TODO: chamar repositório que grava a solicitação e retorna o número da autorização.
    final snack = SnackBar(
      content: Text(
        'OK! Beneficiário: ${_selBenef!.nome}\n'
            'Especialidade: ${_selEsp!.name}\n'
            'Cidade: ${_selCidade!.name}\n'
            'Prestador: ${_selPrest!.name}\n'
            '(A persistência será feita via repositório.)',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);
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
              // ===== Beneficiário =====
              SectionCard(
                title: 'Beneficiário',
                child: DropdownButtonFormField<_Beneficiario>(
                  isExpanded: true,
                  value: _selBenef,
                  items: _beneficiarios.map((b) {
                    final isTitular = b.idDep == 0;
                    return DropdownMenuItem(
                      value: b,
                      child: Text(isTitular ? '${b.nome} (Titular)' : b.nome),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selBenef = v),
                  decoration: _inputDeco('Selecione o beneficiário'),
                ),
              ),
              const SizedBox(height: 12),

              // ===== Especialidade =====
              SectionCard(
                title: 'Especialidade',
                child: DropdownButtonFormField<_Item>(
                  isExpanded: true,
                  value: _selEsp,
                  items: _especialidades
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selEsp = v;
                      _selPrest = null; // reset prestador ao mudar filtro
                    });
                  },
                  decoration: _inputDeco('Escolha a especialidade'),
                ),
              ),
              const SizedBox(height: 12),

              // ===== Cidade =====
              SectionCard(
                title: 'Cidade',
                child: DropdownButtonFormField<_Item>(
                  isExpanded: true,
                  value: _selCidade,
                  items: _cidades
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selCidade = v;
                      _selPrest = null; // reset prestador ao mudar filtro
                    });
                  },
                  decoration: _inputDeco('Selecione a cidade'),
                ),
              ),
              const SizedBox(height: 12),

              // ===== Prestador =====
              SectionCard(
                title: 'Prestador',
                child: DropdownButtonFormField<_Prestador>(
                  isExpanded: true,
                  value: _selPrest,
                  items: _prestadoresFiltrados
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                      .toList(),
                  onChanged: (_selCidade == null)
                      ? null
                      : (v) => setState(() => _selPrest = v),
                  decoration: _inputDeco(
                    _selCidade == null
                        ? 'Selecione a cidade primeiro'
                        : 'Escolha o prestador',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ===== Botão =====
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kBrand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _formOk ? _onSubmit : null,
                  child: const Text(
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      borderSide: const BorderSide(color: kBrand, width: 1.6),
    ),
  );
}

// ====== Tipos internos mínimos ======
class _Beneficiario {
  final int idMat;
  final int idDep; // 0 = titular
  final String nome;
  const _Beneficiario({required this.idMat, required this.idDep, required this.nome});
}

class _Item {
  final int id;
  final String name;
  const _Item(this.id, this.name);
}

class _Prestador {
  final int id;
  final String name;
  final int idCidade;
  final List<int> especialidades; // ids de especialidade aceitas
  const _Prestador(this.id, this.name, {required this.idCidade, required this.especialidades});
}

// Dart <3.0 compat
extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
