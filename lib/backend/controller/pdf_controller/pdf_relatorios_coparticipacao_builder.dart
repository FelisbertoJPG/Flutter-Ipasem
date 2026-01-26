import 'package:flutter/services.dart' show rootBundle, Uint8List;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../common/models/relatorio_coparticipacao.dart';
import '../../../common/models/relatorio_irpf.dart';

final _currencyFmt = NumberFormat.simpleCurrency(locale: 'pt_BR');
final _decimalFmt = NumberFormat.decimalPattern('pt_BR');

Future<pw.ImageProvider?> _loadLogo() async {
  try {
    final data = await rootBundle.load('assets/images/icons/logo_ipasem.png');
    return pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

String _money(num? v) {
  if (v == null) return _currencyFmt.format(0);
  return _currencyFmt.format(v);
}

double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final direct = double.tryParse(s);
  if (direct != null) return direct;
  final normalized = s.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(normalized);
}

String _string(Map<String, dynamic> raw, String key) {
  final v = raw[key];
  if (v == null) return '';
  final s = v.toString();
  return s == 'null' ? '' : s;
}

String _buildMesAno(Map<String, dynamic> raw) {
  final m = _string(raw, 'mes');
  final a = _string(raw, 'ano');
  if (m.isEmpty && a.isEmpty) return '';
  if (m.isEmpty) return a;
  if (a.isEmpty) return m;
  return '$m/$a';
}

String _formatDate(dynamic v) {
  if (v == null) return '';
  if (v is DateTime) {
    return DateFormat('dd/MM/yyyy').format(v);
  }
  final s = v.toString().trim();
  if (s.isEmpty) return '';
  try {
    final onlyDate = s.split(' ').first;
    final dt = DateTime.tryParse(onlyDate);
    if (dt != null) {
      return DateFormat('dd/MM/yyyy').format(dt);
    }
  } catch (_) {
    // ignore
  }
  return s;
}

/// Decimais “secos”, igual Yii::$app->formatter->asDecimal(...)
String _moneyFromRaw(Map<String, dynamic> raw, String key) {
  final n = _parseDouble(raw[key]);
  if (n == null) return '';
  return _decimalFmt.format(n);
}

String _percentFromRaw(Map<String, dynamic> raw, String key) {
  final n = _parseDouble(raw[key]);
  if (n == null) return '';
  return '${n.toStringAsFixed(0)}%';
}

String _percentInverseFromRaw(Map<String, dynamic> raw, String key) {
  final n = _parseDouble(raw[key]);
  if (n == null) return '';
  final inv = 100 - n;
  return '${inv.toStringAsFixed(0)}%';
}

/// ======================================================================
/// 1) EXTRATO DE COPARTICIPAÇÃO
/// ======================================================================

Future<Uint8List> buildExtratoCoparticipacaoPdf(
    RelatorioCoparticipacaoData d,
    ) async {
  final logo = await _loadLogo();
  final nowStr = DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.now());

  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (context) {
        return [
          _headerExtrato(logo, nowStr, d),
          pw.SizedBox(height: 8),
          _tabelaExtratos(d),
          _barraTotalExtrato(d),
          pw.SizedBox(height: 18),
          _resumoFinanceiro(d),
        ];
      },
    ),
  );

  return doc.save();
}

pw.Widget _headerExtrato(
    pw.ImageProvider? logo,
    String nowStr,
    RelatorioCoparticipacaoData d,
    ) {
  final entrada = d.periodo.entrada;

  final periodoStr =
      'Período: ${entrada.dataInicio ?? '--/----'} → ${entrada.dataFim ?? '--/----'}';

  String? matriculaStr;
  if (d.usuario?.idmatricula != null) {
    final nome = (d.usuario?.nomeTitular ?? '').trim();
    matriculaStr = 'Matrícula: ${d.usuario!.idmatricula}'
        '${nome.isNotEmpty ? ' - $nome' : ''}';
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null) pw.Image(logo, width: 70),
          if (logo != null) pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Text(
              'EXTRATO DE COPARTICIPAÇÃO',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'Data: $nowStr',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(width: 18),
          pw.Text(
            periodoStr,
            style: const pw.TextStyle(fontSize: 9),
          ),
          if (matriculaStr != null) ...[
            pw.SizedBox(width: 18),
            pw.Text(
              matriculaStr,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ],
      ),
    ],
  );
}

pw.Widget _tabelaExtratos(RelatorioCoparticipacaoData d) {
  final headerStyle = pw.TextStyle(
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
  );
  const cellStyle = pw.TextStyle(fontSize: 9);

  pw.Widget th(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
    child: pw.Text(
      text,
      style: headerStyle,
      textAlign: pw.TextAlign.center,
    ),
  );

  pw.Widget td(
      String text, {
        pw.TextAlign align = pw.TextAlign.left,
      }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 3),
        child: pw.Text(
          text,
          style: cellStyle,
          textAlign: align,
        ),
      );

  final rows = <pw.TableRow>[];

  // Cabeçalho
  rows.add(
    pw.TableRow(
      children: [
        th('Matr.'),
        th('Seq.'),
        th('Nome'),
        th('Subtipo Serv.'),
        th('Mês/Ano'),
        th('Realizado'),
        th('Nº Proc.'),
        th('Valor Proc.'),
        th('Qtd'),
        th('Cobert.'),
        th('Copart.'),
        th('Valor Taxa'),
        th('Copart.'),
        th('Médico'),
      ],
    ),
  );

  rows.add(
    pw.TableRow(
      children: [
        td(''),
        td(''),
        td(''),
        td('Descrição AMB'),
        td(''),
        td(''),
        td(''),
        td('Obs.'),
        td(''),
        td(''),
        td(''),
        td(''),
        td(''),
        td('Vínculo'),
      ],
    ),
  );

  for (final e in d.extratos) {
    final r = e.raw;

    final matricula = _string(r, 'matricula');
    final dependente = _string(r, 'dependente');
    final nomePessoa = _string(r, 'nome_pessoa');
    final subtipo = _string(r, 'subtipo_servico');

    final mesAno = (_string(r, 'mes_ao').isNotEmpty)
        ? _string(r, 'mes_ao')
        : _buildMesAno(r);

    final dtReal = _formatDate(r['dt_realizacao']);
    final nroProc = _string(r, 'nro_processo');
    final valorProc = _moneyFromRaw(r, 'valor_procedimento');
    final qtde = _string(r, 'qtde');
    final percCob = _percentFromRaw(r, 'perc_cobertura');
    final percCopart = _percentInverseFromRaw(r, 'perc_cobertura');
    final valorTaxa = _moneyFromRaw(r, 'valor_taxa');
    final valorTotal = _moneyFromRaw(r, 'valor_total');
    final medico =
    '${_string(r, "tipo_medico")} ${_string(r, "nome_medico")}'.trim();

    final descAmb = _string(r, 'descricao_amb');
    final obs = _string(r, 'obs');
    final vinculo =
    '${_string(r, "tipo_vinculo")} ${_string(r, "nome_vinculo")}'.trim();

    rows.add(
      pw.TableRow(
        children: [
          td(matricula, align: pw.TextAlign.center),
          td(dependente, align: pw.TextAlign.center),
          td(nomePessoa),
          td(subtipo),
          td(mesAno, align: pw.TextAlign.center),
          td(dtReal, align: pw.TextAlign.center),
          td(nroProc, align: pw.TextAlign.center),
          td(valorProc, align: pw.TextAlign.right),
          td(qtde, align: pw.TextAlign.center),
          td(percCob, align: pw.TextAlign.center),
          td(percCopart, align: pw.TextAlign.center),
          td(valorTaxa, align: pw.TextAlign.right),
          td(valorTotal, align: pw.TextAlign.right),
          td(medico),
        ],
      ),
    );

    rows.add(
      pw.TableRow(
        children: [
          pw.Container(),
          pw.Container(),
          pw.Container(),
          td(descAmb),
          pw.Container(),
          pw.Container(),
          pw.Container(),
          td(obs),
          pw.Container(),
          pw.Container(),
          pw.Container(),
          pw.Container(),
          pw.Container(),
          td(vinculo),
        ],
      ),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(width: 0.5, color: PdfColors.black),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    columnWidths: const {
      0: pw.FlexColumnWidth(0.9),
      1: pw.FlexColumnWidth(0.7),
      2: pw.FlexColumnWidth(2.5),
      3: pw.FlexColumnWidth(2.0),
      4: pw.FlexColumnWidth(1.0),
      5: pw.FlexColumnWidth(1.1),
      6: pw.FlexColumnWidth(1.2),
      7: pw.FlexColumnWidth(1.2),
      8: pw.FlexColumnWidth(0.7),
      9: pw.FlexColumnWidth(0.8),
      10: pw.FlexColumnWidth(0.8),
      11: pw.FlexColumnWidth(1.2),
      12: pw.FlexColumnWidth(1.2),
      13: pw.FlexColumnWidth(2.4),
    },
    children: rows,
  );
}

pw.Widget _barraTotalExtrato(RelatorioCoparticipacaoData d) {
  final totalSegurado = d.totaisPagos.valorTotal ?? 0.0;
  return pw.Container(
    width: double.infinity,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(width: 0.5, color: PdfColors.black),
    ),
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
    alignment: pw.Alignment.center,
    child: pw.Text(
      'Total de Coparticipação do Segurado: ${_money(totalSegurado)}',
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.Widget _resumoFinanceiro(RelatorioCoparticipacaoData d) {
  final t = d.totais;
  final p = d.totaisPagos;

  pw.TableRow _linha(
      String label,
      double valor,
      String sufixo, {
        bool negrito = false,
      }) {
    final style = pw.TextStyle(
      fontSize: 10,
      fontWeight: negrito ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(label, style: style),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(
            '${_money(valor)}${sufixo.isNotEmpty ? ' ($sufixo)' : ''}',
            style: style,
          ),
        ),
      ],
    );
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Center(
        child: pw.Text(
          'RESUMO FINANCEIRO',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Total Pago pelo IPASEM: ${_money(p.totalPago ?? 0)}',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.Text(
            'Total de Coparticipação do Segurado: ${_money(p.valorTotal ?? 0)}',
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
              },
              children: [
                _linha(
                  'Saldo do Mês(es) Anterior(es):',
                  t.A_saldoMesesAnteriores,
                  'A',
                ),
                _linha(
                  'Total de Coparticipação:',
                  t.B_totalCoparticipacao,
                  'B',
                ),
                _linha('Débitos Avulsos', t.C_debitosAvulsos, 'C'),
                _linha(
                  'Total de Débitos',
                  t.ABC_debitosTotal,
                  'A+B+C',
                  negrito: true,
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 30),
          pw.Expanded(
            child: pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
              },
              children: [
                _linha(
                  'Enviado para desconto:',
                  t.totalEnviadoDesconto,
                  '',
                ),
                _linha(
                  'Descontado Coparticipação:',
                  t.D_descontadoCopart,
                  'D',
                ),
                _linha('Créditos Avulsos', t.E_creditosAvulsos, 'E'),
                _linha(
                  'Total de Créditos',
                  t.DE_creditosTotal,
                  'D+E',
                  negrito: true,
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Center(
        child: pw.Column(
          children: [
            pw.Text(
              'Saldo de Coparticipação a Transportar: '
                  '${_money(t.saldoATransportar)}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              '(A+B+C) - (D+E)',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    ],
  );
}

/// ======================================================================
/// 2) DEMONSTRATIVO / IRPF
/// ======================================================================

Future<Uint8List> buildIrpfDemonstrativoPdf(
    RelatorioIrpfData d,
    ) async {
  // Inicializa símbolos de data para pt_BR (necessário para MMMM, etc.)
  await initializeDateFormatting('pt_BR', null);

  final logo = await _loadLogo();
  final ano = d.periodo.anoInicio ?? DateTime.now().year;
  final nomeTitular = (d.usuario?.nomeTitular ?? '').trim();
  final hojeLong =
  DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(DateTime.now());

  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) {
        return [
          if (logo != null) pw.Center(child: pw.Image(logo, width: 140)),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'Demonstrativo de Valores de Coparticipação',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'Ano Calendário $ano',
              style: const pw.TextStyle(fontSize: 12),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Informamos que os valores de coparticipação referente ao ano de $ano, '
                'relacionados abaixo, foram descontados do(a) '
                '${nomeTitular.isEmpty ? 'segurado(a)' : nomeTitular}.',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '* Os valores de coparticipação e reembolso estão discriminados por usuário.\n'
                '** Informamos que não existem descontos para nenhum outro dependente.',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.SizedBox(height: 18),
          _tabelaIrpfSecao(
            titulo: 'Valores Pagos de Coparticipação',
            itens: d.pago,
            total: d.totais.totalPago,
          ),
          pw.SizedBox(height: 24),
          _tabelaIrpfSecao(
            titulo: 'Parcela Dedutível/Valor Reembolsado',
            itens: d.dedutivel,
            total: d.totais.totalDedutivel,
          ),
          pw.SizedBox(height: 32),
          pw.Center(
            child: pw.Text(
              'Novo Hamburgo, $hojeLong',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('______________________________'),
                pw.Text('Maria Cristina Schmitt'),
                pw.Text('Diretora-Presidente'),
              ],
            ),
          ),
        ];
      },
    ),
  );

  return doc.save();
}

pw.Widget _tabelaIrpfSecao({
  required String titulo,
  required List<IrpfItem> itens,
  required double total,
}) {
  final headerStyle = pw.TextStyle(
    fontSize: 11,
    fontWeight: pw.FontWeight.bold,
  );
  final cellHeaderStyle = pw.TextStyle(
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
  );
  const cellStyle = pw.TextStyle(fontSize: 10);

  pw.Widget th(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      style: cellHeaderStyle,
      textAlign: pw.TextAlign.center,
    ),
  );

  pw.Widget td(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          text,
          style: cellStyle,
          textAlign: align,
        ),
      );

  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        th('Matrícula'),
        th('Depto'),
        th('Nome do Titular'),
        th('Nome do Dependente'),
        th('Valor'),
      ],
    ),
  ];

  if (itens.isEmpty) {
    rows.add(
      pw.TableRow(
        children: [
          td('-', align: pw.TextAlign.center),
          td('-', align: pw.TextAlign.center),
          td('-'),
          td('-'),
          td(_currencyFmt.format(0), align: pw.TextAlign.right),
        ],
      ),
    );
  } else {
    for (final it in itens) {
      rows.add(
        pw.TableRow(
          children: [
            td(
              it.idmatricula?.toString() ?? '-',
              align: pw.TextAlign.center,
            ),
            td(
              it.iddependente?.toString() ?? '-',
              align: pw.TextAlign.center,
            ),
            td(it.nomeTitular ?? '-'),
            td(it.nomeDependente ?? '-'),
            td(
              _money(it.valor ?? 0),
              align: pw.TextAlign.right,
            ),
          ],
        ),
      );
    }
  }

  rows.add(
    pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Center(
            child: pw.Text(
              'Valor Total',
              style: headerStyle,
            ),
          ),
        ),
        pw.Container(),
        pw.Container(),
        pw.Container(),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            _money(total),
            style: headerStyle,
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    ),
  );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Center(
        child: pw.Text(
          titulo,
          style: headerStyle,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5, color: PdfColors.black),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.3),
          1: const pw.FlexColumnWidth(1.0),
          2: const pw.FlexColumnWidth(3.0),
          3: const pw.FlexColumnWidth(3.0),
          4: const pw.FlexColumnWidth(1.8),
        },
        children: rows,
      ),
    ],
  );
}
