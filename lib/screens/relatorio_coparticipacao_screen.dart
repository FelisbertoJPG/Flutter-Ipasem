// lib/screens/relatorio_coparticipacao_screen.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_router.dart';
import '../theme/colors.dart';
import '../ui/app_shell.dart';
import '../ui/components/section_card.dart';

import '../models/relatorio_coparticipacao_models.dart';

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

  bool _busy = false;
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
  }

  @override
  void dispose() {
    _inicioCtrl.dispose();
    _fimCtrl.dispose();
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
      final dio = ApiRouter.client(); // mesmo cliente central

      final resp = await dio.post(
        '',
        queryParameters: {'action': 'relatorio_coparticipacao'},
        data: {
          'idmatricula': widget.idMatricula,
          'data_inicio': _inicioCtrl.text.trim(), // "MM/YYYY"
          'data_fim': _fimCtrl.text.trim(),       // "MM/YYYY"
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final payload = resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : json.decode(resp.data as String) as Map<String, dynamic>;

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
            SectionCard(
              title: 'Período',
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
                          'Consultar',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
              _buildPeriodoUsuario(_data!),
              const SizedBox(height: 12),
              _buildTotais(_data!),
              const SizedBox(height: 12),
              _buildCopar(_data!),
              const SizedBox(height: 12),
              _buildExtratos(_data!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodoUsuario(RelatorioCoparticipacaoData d) {
    final en = d.periodo.entrada;
    final ef = d.periodo.efetivo;

    return SectionCard(
      title: 'Resumo do Período',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Entrada', '${en.dataInicio ?? '—'} → ${en.dataFim ?? '—'}'),
          const SizedBox(height: 6),
          _kv(
            'Efetivo',
            '${ef.mesInicio?.toString().padLeft(2, '0') ?? '--'}/${ef.anoInicio ?? '----'}'
                ' → ${ef.mesFim?.toString().padLeft(2, '0') ?? '--'}/${ef.anoFim ?? '----'}',
          ),
          if (d.usuario?.idmatricula != null) ...[
            const SizedBox(height: 6),
            _kv('Matrícula', d.usuario!.idmatricula.toString()),
          ],
          if ((d.usuario?.nomeTitular ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            _kv('Titular', d.usuario!.nomeTitular!),
          ],
        ],
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

  Widget _buildCopar(RelatorioCoparticipacaoData d) {
    if (d.copar.isEmpty) {
      return const SectionCard(
        title: 'Caixas do Período',
        child: Text('Sem lançamentos no período.'),
      );
    }

    return SectionCard(
      title: 'Caixas do Período',
      child: Column(
        children: [
          for (final it in d.copar)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPanelBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPanelBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tipo ${it.tipoCaixa ?? '-'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(_brMoney(it.total)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExtratos(RelatorioCoparticipacaoData d) {
    if (d.extratos.isEmpty) {
      return const SectionCard(
        title: 'Extratos',
        child: Text('Nenhum item de extrato retornado para o período.'),
      );
    }

    return SectionCard(
      title: 'Extratos',
      child: Column(
        children: [
          for (final e in d.extratos)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kCardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      e.descricao ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      e.competencia ?? '—',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF475467)),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _brMoney(e.valor),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
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

  Widget _kv(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$k: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: kBrand,
          ),
        ),
        Expanded(child: Text(v)),
      ],
    );
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
