import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../backend/controller/pdf_controller/pdf_relatorios_coparticipacao_builder.dart';
import '../../../common/config/dev_api.dart';
import '../../../common/models/relatorio_coparticipacao.dart';
import '../../../common/models/relatorio_irpf.dart';
import '../../theme/colors.dart';
import '../components/cards/section_card.dart';
import '../layouts/app_shell.dart';

class RelatorioCoparticipacaoScreen extends StatefulWidget {
  final int idMatricula;

  const RelatorioCoparticipacaoScreen({
    super.key,
    required this.idMatricula,
  });

  @override
  State<RelatorioCoparticipacaoScreen> createState() =>
      _RelatorioCoparticipacaoScreenState();
}

class _RelatorioCoparticipacaoScreenState
    extends State<RelatorioCoparticipacaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inicioCtrl = TextEditingController();
  final _fimCtrl = TextEditingController();

  // Ano para o IRPF (AAAA)
  final _anoIrpfCtrl = TextEditingController();

  // Cliente central da API (/api/v1) – usa ApiRouter.apiRootUri por baixo
  final DevApi _api = DevApi();

  bool _busy = false;
  bool _generatingPdf = false;
  bool _generatingIrpfPdf = false;

  RelatorioCoparticipacaoData? _data;
  String? _error;

  final _fmtCurrency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  @override
  void initState() {
    super.initState();
    // Preenche com mês/ano atuais no formato MM/YYYY
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    _inicioCtrl.text = '$mm/${now.year}';
    _fimCtrl.text = '$mm/${now.year}';

    // Ano atual para IRPF
    _anoIrpfCtrl.text = now.year.toString();
  }

  @override
  void dispose() {
    _inicioCtrl.dispose();
    _fimCtrl.dispose();
    _anoIrpfCtrl.dispose();
    super.dispose();
  }

  /// Aplica máscara MM/AAAA a um texto contendo mês/ano.
  ///
  /// Exemplos:
  /// - "092025"      -> "09/2025"
  /// - "09-2025"     -> "09/2025"
  /// - "09/2025"     -> "09/2025" (mantém)
  /// - "09/25"       -> permanece "09/25" (vai falhar na validação e mostrar erro)
  String _applyMmYyyyMask(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return raw;

    // Mantém apenas dígitos
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) {
      // Não temos 6 dígitos (MM + AAAA) -> mantém como está
      return raw;
    }
    if (digits.length > 6) {
      digits = digits.substring(0, 6);
    }

    final mm = digits.substring(0, 2);
    final yyyy = digits.substring(2, 6);
    return '$mm/$yyyy';
  }

  /// Normaliza ambos os campos para MM/AAAA antes de validar/enviar.
  void _normalizeInputs() {
    _inicioCtrl.text = _applyMmYyyyMask(_inicioCtrl.text);
    _fimCtrl.text = _applyMmYyyyMask(_fimCtrl.text);
  }

  /// Extrai uma mensagem de erro amigável a partir de um payload de backend.
  ///
  /// Tenta usar:
  /// - message
  /// - msg
  /// - error_description
  /// - error
  /// e, se existir, adiciona o EID/código no final.
  String _extractBackendError(
      dynamic data, {
        String fallback = 'Falha ao consultar. Tente novamente.',
      }) {
    if (data == null) return fallback;

    // Se já for String, usa direto (desde que não vazia).
    if (data is String) {
      final s = data.trim();
      return s.isEmpty ? fallback : s;
    }

    if (data is Map) {
      final map = data.cast<String, dynamic>();
      final msg = (map['message'] ??
          map['msg'] ??
          map['error_description'] ??
          map['error'])
          ?.toString();
      final eid = map['eid']?.toString();

      String base;
      if (msg != null && msg.trim().isNotEmpty) {
        base = msg.trim();
      } else {
        base = fallback;
      }

      if (eid != null && eid.trim().isNotEmpty) {
        return '$base (código: $eid)';
      }
      return base;
    }

    // Qualquer outra coisa: tenta toString, se não, fallback.
    final s = data.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Future<void> _fetch() async {
    // Primeiro normaliza para MM/AAAA
    _normalizeInputs();

    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Endpoint REST atual: POST /api/v1/relatorio/coparticipacao
      final resp = await _api.postRest<dynamic>(
        '/relatorio/coparticipacao',
        data: {
          'idmatricula': widget.idMatricula,
          'data_inicio': _inicioCtrl.text.trim(), // "MM/YYYY"
          'data_fim': _fimCtrl.text.trim(), // "MM/YYYY"
        },
      );

      final raw = resp.data;
      if (raw is! Map) {
        throw Exception('Resposta inesperada do servidor.');
      }

      final payload = raw.cast<String, dynamic>();
      final parsed = RelatorioResponse.fromMap(payload);

      if (!parsed.ok) {
        // Tenta extrair mensagem detalhada do próprio payload.
        final msg = _extractBackendError(
          payload,
          fallback: 'Falha ao consultar. Tente novamente.',
        );
        setState(() {
          _busy = false;
          _error = msg;
        });
        return;
      }

      setState(() {
        _data = parsed.data;
        _busy = false;
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data != null
          ? _extractBackendError(
        data,
        fallback: e.message ?? 'Erro de rede.',
      )
          : (e.message ?? 'Erro de rede.');

      setState(() {
        _busy = false;
        _error = msg;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Erro inesperado: $e';
      });
    }
  }

  /// Gera e abre o PDF do extrato atual usando o builder em
  /// pdf_relatorios_coparticipacao_builder.dart.
  Future<void> _exportExtratoPdf() async {
    final data = _data;
    if (data == null) return;

    setState(() {
      _generatingPdf = true;
    });

    try {
      final bytes = await buildExtratoCoparticipacaoPdf(data);

      // Abre o preview/diálogo de impressão nativo (mobile/web/desktop)
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao gerar PDF: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingPdf = false;
        });
      }
    }
  }

  /// Validação simples de ano AAAA.
  String? _validateYear(String? v) {
    final s = (v ?? '').trim();
    if (!RegExp(r'^\d{4}$').hasMatch(s)) {
      return 'Use o formato AAAA';
    }
    return null;
  }

  /// Consulta o backend de IRPF e gera o PDF anual.
  ///
  /// Ajuste o endpoint '/relatorio/irpf' se no teu backend o caminho for outro.
  Future<void> _exportIrpfPdf() async {
    final err = _validateYear(_anoIrpfCtrl.text);
    if (err != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }

    final ano = int.parse(_anoIrpfCtrl.text.trim());

    setState(() {
      _generatingIrpfPdf = true;
      // não mexe em _data / _busy; é uma consulta independente
    });

    try {
      final resp = await _api.postRest<dynamic>(
        '/relatorio/irpf',
        data: {
          'idmatricula': widget.idMatricula,
          'ano_inicio': ano, // <- o que o backend está pedindo
          'ano_fim': ano,    // se a API aceitar intervalo, já manda igual
        },
      );


      final raw = resp.data;
      if (raw is! Map) {
        throw Exception('Resposta inesperada do servidor.');
      }

      final payload = raw.cast<String, dynamic>();

      if (payload['ok'] != true) {
        final msg = _extractBackendError(
          payload,
          fallback: 'Falha ao consultar IRPF. Tente novamente.',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return;
      }

      final dataMap = payload['data'];
      if (dataMap is! Map) {
        throw Exception('Dados do IRPF ausentes.');
      }

      final irpfData =
      RelatorioIrpfData.fromMap(dataMap.cast<String, dynamic>());

      final bytes = await buildIrpfDemonstrativoPdf(irpfData);
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data != null
          ? _extractBackendError(
        data,
        fallback: e.message ?? 'Erro de rede.',
      )
          : (e.message ?? 'Erro de rede.');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar IRPF: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingIrpfPdf = false;
        });
      }
    }
  }

  String _brMoney(num? v) {
    if (v == null) return '—';
    return _fmtCurrency.format(v);
  }

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kCardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBrand, width: 1.6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final title = 'Extrato de Coparticipação';

    return AppScaffold(
      title: title,
      body: RefreshIndicator(
        onRefresh: () async {
          if (_data != null) await _fetch();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // === Extrato mensal ===
            SectionCard(
              title: 'Período (Extrato de Coparticipação)',
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _inicioCtrl,
                              keyboardType: TextInputType.datetime,
                              decoration: _deco(
                                'Início',
                                hint: 'MM/AAAA (ex.: 09/2025)',
                              ),
                              validator: _validateMonthYear,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _fimCtrl,
                              keyboardType: TextInputType.datetime,
                              decoration: _deco(
                                'Fim',
                                hint: 'MM/AAAA (ex.: 11/2025)',
                              ),
                              validator: _validateMonthYear,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: kBrand,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _busy ? null : _fetch,
                          child: _busy
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                              : const Text(
                            'Consultar Extrato',
                            style:
                            TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      if (_data != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed:
                            _generatingPdf ? null : _exportExtratoPdf,
                            icon: _generatingPdf
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                                : const Icon(Icons.receipt_long_outlined),
                            label: const Text(
                              'Baixar Extrato em PDF',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // === IRPF anual ===
            SectionCard(
              title: 'Extrato de coparticipação - IRPF',
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _anoIrpfCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: _deco(
                        'Ano',
                        hint: 'AAAA (ex.: ${DateTime.now().year})',
                      ).copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed:
                        _generatingIrpfPdf ? null : _exportIrpfPdf,
                        icon: _generatingIrpfPdf
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.article_outlined),
                        label: const Text(
                          'Baixar Demonstrativo IRPF (PDF)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBox(message: _error!),
            ],

            if (_data != null) ...[
              const SizedBox(height: 12),
              _buildTotais(_data!),
              const SizedBox(height: 12),
              //_buildCopar(_data!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotais(RelatorioCoparticipacaoData d) {
    final t = d.totais;

    Widget cell(String label, String value) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475467),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return SectionCard(
      title: 'Totais',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: cell(
                  'A — Saldo Meses Anteriores',
                  _brMoney(t.A_saldoMesesAnteriores),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: cell(
                  'B — Total Coparticipação',
                  _brMoney(t.B_totalCoparticipacao),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: cell(
                  'C — Débitos Avulsos',
                  _brMoney(t.C_debitosAvulsos),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: cell(
                  'D — Descontado Copart.',
                  _brMoney(t.D_descontadoCopart),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: cell(
                  'E — Créditos Avulsos',
                  _brMoney(t.E_creditosAvulsos),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: cell(
                  'ABC — Débitos Totais',
                  _brMoney(t.ABC_debitosTotal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: cell(
                  'DE — Créditos Totais',
                  _brMoney(t.DE_creditosTotal),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: cell(
                  'Saldo a Transportar',
                  _brMoney(t.saldoATransportar),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: cell(
                  'Total Enviado para Desconto',
                  _brMoney(t.totalEnviadoDesconto),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: cell(
                  'Total Pago (período)',
                  _brMoney(d.totaisPagos.totalPago ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  String? _validateMonthYear(String? v) {
    final s = (v ?? '').trim();
    final re = RegExp(r'^\d{2}/\d{4}$');
    if (!re.hasMatch(s)) return 'Use o formato MM/AAAA';
    final mm = int.tryParse(s.substring(0, 2)) ?? 0;
    if (mm < 1 || mm > 12) return 'Mês inválido';
    return null;
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C2C7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB42318)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB42318)),
            ),
          ),
        ],
      ),
    );
  }
}
