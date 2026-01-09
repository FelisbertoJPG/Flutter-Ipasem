// lib/screens/carteirinha_selecionar_beneficiario.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../common/models/dependent.dart';
import '../../../../common/config/api_router.dart';
import '../../../../common/config/dev_api.dart';
import '../../../../common/services/session.dart';

/// Abre um bottom-sheet para escolher o beneficiário (Titular ou dependentes).
/// Retorna o idDependente escolhido (0 = titular) ou null se cancelado.
Future<int?> showBeneficiaryPickerSheet(
    BuildContext context, {
      required int idMatricula,
      DevApi? api,
    }) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BeneficiarySheet(idMatricula: idMatricula, api: api),
  );
}

class _BeneficiarySheet extends StatefulWidget {
  final int idMatricula;
  final DevApi? api;

  const _BeneficiarySheet({
    super.key,
    required this.idMatricula,
    this.api,
  });

  @override
  State<_BeneficiarySheet> createState() => _BeneficiarySheetState();
}

class _BeneficiarySheetState extends State<_BeneficiarySheet> {
  DevApi? _api; // resolvida em didChangeDependencies
  bool _apiReady = false;

  bool _loading = true;
  String? _warning; // mensagem leve quando cair em fallback
  List<Dependent> _deps = [];
  int _selectedIdDep = 0; // 0 = Titular

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Resolve a API UMA vez: prioriza a injetada; senão usa a base padrão do app (ApiRouter)
    if (!_apiReady) {
      _api = widget.api ?? ApiRouter.client();
      _apiReady = true;
      _load(); // dispara o fetch após resolver a API correta
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _warning = null;
    });

    try {
      final profile = await Session.getProfile();
      // Se não tiver profile, tratamos como titular (comportamento padrão)
      final cpfProfileDigits =
      (profile?.cpf ?? '').replaceAll(RegExp(r'\D'), '');

      List<Dependent> list = const [];

      try {
        list = await _api!.fetchDependentes(widget.idMatricula);
      } catch (_) {
        // Se falhar a chamada, seguimos com lista vazia e usamos fallback abaixo
        list = const [];
      }

      // Tenta localizar o titular vindo do backend (iddependente == 0)
      Dependent? titular;
      for (final d in list) {
        if (d.iddependente == 0) {
          titular = d;
          break;
        }
      }

      // Se backend não mandar titular, cria um sintético usando profile (quando existir)
      titular ??= Dependent(
        nome: profile?.nome ?? 'Titular',
        idmatricula: widget.idMatricula,
        iddependente: 0,
        sexo: profile?.sexoTxt ?? profile?.sexo ?? 'M',
        cpf: profile?.cpf ?? '',
        dtNasc: null,
        idade: null,
      );

      final outros = list.where((d) => d.iddependente != 0).toList();

      // ===== Detecta se o login atual é de DEPENDENTE =====
      bool isDependentLogin = false;
      Dependent? selfDep;

      if (profile != null) {
        // 1) Tentativa via idDependente (quando preenchido)
        final rawIdDep = profile.idDependente;
        if (rawIdDep != null && rawIdDep > 0) {
          final depId = rawIdDep.abs();
          for (final d in outros) {
            if (d.iddependente == depId || d.iddependente == -depId) {
              selfDep = d;
              break;
            }
          }
          if (selfDep != null) {
            isDependentLogin = true;
          } else {
            // 2) Se não achou por id, tenta por CPF
            if (cpfProfileDigits.isNotEmpty) {
              for (final d in outros) {
                final depCpfDigits =
                (d.cpf ?? '').replaceAll(RegExp(r'\D'), '');
                if (depCpfDigits.isNotEmpty &&
                    depCpfDigits == cpfProfileDigits) {
                  selfDep = d;
                  isDependentLogin = true;
                  break;
                }
              }
            }
          }

          // Se ainda não encontrou, mas sabemos que é login de dependente,
          // criamos um registro sintético com base no profile.
          if (selfDep == null) {
            isDependentLogin = true;
            selfDep = Dependent(
              nome: profile.nome,
              idmatricula: widget.idMatricula,
              iddependente: depId,
              sexo: profile.sexoTxt ?? profile.sexo,
              cpf: profile.cpf,
              dtNasc: null,
              idade: null,
            );
            _warning =
            'Não foi possível consultar todos os beneficiários. Exibindo apenas o dependente logado.';
          }
        } else {
          // 3) Fallback: se idDependente não veio, tenta detectar por CPF
          if (cpfProfileDigits.isNotEmpty) {
            for (final d in outros) {
              final depCpfDigits =
              (d.cpf ?? '').replaceAll(RegExp(r'\D'), '');
              if (depCpfDigits.isNotEmpty &&
                  depCpfDigits == cpfProfileDigits &&
                  d.iddependente != 0) {
                selfDep = d;
                isDependentLogin = true;
                break;
              }
            }
          }
        }
      }

      List<Dependent> finais;

      if (isDependentLogin && selfDep != null) {
        // Login de dependente: exibe APENAS o dependente logado
        finais = [selfDep];
        _selectedIdDep = selfDep.iddependente;
      } else {
        // Login de titular (ou falha em detectar dependente):
        // mantém comportamento padrão: Titular + demais dependentes
        finais = [titular, ...outros];
        _selectedIdDep = 0;
      }

      if (!mounted) return;
      setState(() {
        _deps = finais;
        _loading = false;
      });
    } catch (_) {
      // Fallback “gracioso”: exibe ao menos o Titular para permitir emitir a carteirinha
      if (!mounted) return;
      setState(() {
        _deps = [
          Dependent(
            nome: 'Titular',
            idmatricula: widget.idMatricula,
            iddependente: 0,
            sexo: 'M',
            cpf: '',
            dtNasc: null,
            idade: null,
          )
        ];
        _selectedIdDep = 0;
        _warning ??=
        'Não foi possível consultar beneficiários. Exibindo apenas o Titular.';
        _loading = false;
      });
    }
  }

  IconData _genderIcon(String? s) {
    final v = (s ?? '').trim().toUpperCase();
    if (v == 'F' || v == 'FEMININO' || v == '2') return FontAwesomeIcons.venus;
    return FontAwesomeIcons.mars;
  }

  /// Converte entradas comuns (yyyy-mm-dd, dd/mm/yyyy, dd-mm-yyyy, etc.) para dd-mm-aa
  /// dd-mm-aa (padrão) ou dd-mm-aaaa (se short=false)
  String _fmtDate(String? raw, {bool short = true}) {
    if (raw == null) return '';
    final s = raw.trim();
    if (s.isEmpty) return '';

    DateTime? dt;

    // yyyy-mm-dd (ou yyyy/mm/dd) e variantes com hora
    final mIso = RegExp(r'^(\d{4})[-/](\d{2})[-/](\d{2})').firstMatch(s);
    if (mIso != null) {
      final y = int.parse(mIso.group(1)!);
      final mo = int.parse(mIso.group(2)!);
      final d = int.parse(mIso.group(3)!);
      dt = DateTime(y, mo, d);
    }

    // dd/mm/yyyy ou dd-mm-yyyy
    final mBr = RegExp(r'^(\d{2})[\/-](\d{2})[\/-](\d{4})$').firstMatch(s);
    if (dt == null && mBr != null) {
      final d = int.parse(mBr.group(1)!);
      final mo = int.parse(mBr.group(2)!);
      final y = int.parse(mBr.group(3)!);
      dt = DateTime(y, mo, d);
    }

    // Fallback genérico
    dt ??= DateTime.tryParse(s);

    if (dt == null) return s;

    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final year =
    short ? (dt.year % 100).toString().padLeft(2, '0') : dt.year.toString().padLeft(4, '0');
    return '$dd-$mm-$year';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: const [
              BoxShadow(blurRadius: 16, offset: Offset(0, -4), color: Colors.black26)
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Escolha o beneficiário',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (_warning != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: theme.colorScheme.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _warning!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.secondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      itemCount: _deps.length,
                      itemBuilder: (_, i) {
                        final d = _deps[i];
                        final isTitular = d.iddependente == 0;
                        final selected = _selectedIdDep == d.iddependente;

                        return Card(
                          elevation: selected ? 2 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: selected
                                  ? theme.colorScheme.primary.withOpacity(0.28)
                                  : theme.dividerColor.withOpacity(0.35),
                            ),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () =>
                                setState(() => _selectedIdDep = d.iddependente),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Radio<int>(
                                    value: d.iddependente,
                                    groupValue: _selectedIdDep,
                                    onChanged: (v) =>
                                        setState(() => _selectedIdDep = v ?? 0),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                isTitular
                                                    ? '${d.nome} (Titular)'
                                                    : d.nome,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            if (!isTitular)
                                              Container(
                                                padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                  BorderRadius.circular(999),
                                                  color: theme.colorScheme.primary
                                                      .withOpacity(0.10),
                                                  border: Border.all(
                                                    color: theme.colorScheme.primary
                                                        .withOpacity(0.35),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Dependente',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                    theme.colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 16,
                                          runSpacing: 2,
                                          children: [
                                            if ((d.cpf ?? '').isNotEmpty)
                                              Text('CPF: ${d.cpf}',
                                                  style: theme
                                                      .textTheme.bodySmall),
                                            if (d.dtNasc != null &&
                                                d.dtNasc!.isNotEmpty)
                                              Text(
                                                'Nasc.: ${_fmtDate(d.dtNasc, short: false)}',
                                                style: theme
                                                    .textTheme.bodySmall,
                                              ),
                                            if (d.idade != null)
                                              Text('Idade: ${d.idade}',
                                                  style: theme
                                                      .textTheme.bodySmall),
                                            Text(
                                              'Matr.: ${d.idmatricula}-${d.iddependente}',
                                              style:
                                              theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: theme.colorScheme.primary
                                        .withOpacity(0.10),
                                    child: Icon(
                                      _genderIcon(d.sexo),
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, null),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.pop(context, _selectedIdDep),
                          child: const Text('Confirmar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
