// lib/pdf/pdf_autorizacao.dart
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'autorizacao_pdf_data.dart';

Future<Uint8List> buildAutorizacaoPdf(AutorizacaoPdfData d) async {
  final doc = pw.Document();
  final nowStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

  // Carrega o logo do app como asset (fallback para um box com “LOGO” se não achar)
  pw.ImageProvider? _logo;
  try {
    final data = await rootBundle.load('assets/images/icons/logo_ipasem.png');
    _logo = pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    _logo = null;
  }

  final _bold  = pw.TextStyle(fontWeight: pw.FontWeight.bold);
  final _small = pw.TextStyle(fontSize: 10);
  final _tiny  = pw.TextStyle(fontSize: 9);

  pw.Widget linhaFina() => pw.Container(
    margin: const pw.EdgeInsets.symmetric(vertical: 6),
    height: 1,
    color: PdfColors.grey600,
  );

  String aviso() {
    final c = d.codigoEspecialidade;
    if (c == 100 || c == 140 || c == 570 || c == 700) {
      return '* AUTORIZAÇÃO VÁLIDA SOMENTE NO MÊS DE EMISSÃO!   * REALIZAR O EXAME SOMENTE COM A REQUISIÇÃO MÉDICA ORIGINAL.';
    } else if (c == 120) {
      return '* AUTORIZAÇÃO VÁLIDA POR 2 MESES PARA UMA CONSULTA!   * REALIZAR O EXAME SOMENTE COM A REQUISIÇÃO MÉDICA ORIGINAL.';
    } else if (c == 800 || c == 810 || c == 820) {
      return '* REALIZAR O EXAME SOMENTE COM A REQUISIÇÃO MÉDICA ORIGINAL.';
    }
    return '* AUTORIZAÇÃO VÁLIDA POR 3 MESES PARA UMA CONSULTA!   * REALIZAR O EXAME SOMENTE COM A REQUISIÇÃO MÉDICA ORIGINAL.';
  }

  // Badge de origem (sem preenchimento, só borda)
  pw.Widget etiquetaOrigem() => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Text(
      'Emitido pelo Aplicativo IPASEMNH Digital',
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget header() => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(flex: 1, child: pw.Text('*** IPASEM N.H.***', style: _small)),
      pw.SizedBox(width: 8),
      pw.Expanded(
        flex: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'AUTORIZAÇÃO DE SERVIÇOS COMPLEMENTARES Nº: ${d.numero}',
              style: _bold,
            ),
            pw.SizedBox(height: 4),
            pw.Text('Emissão: ${d.dataEmissao}  |  Impressão: $nowStr', style: _small),
            pw.SizedBox(height: 4),
            pw.Align(alignment: pw.Alignment.centerRight, child: etiquetaOrigem()),
          ],
        ),
      ),
    ],
  );

  pw.Widget prestador() => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _logo != null
          ? pw.Image(_logo!, width: 140, height: 48, fit: pw.BoxFit.contain)
          : pw.Container(
        width: 140,
        height: 48,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600)),
        child: pw.Text('LOGO', style: _tiny),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Prestador de Serviços', style: _bold),
            pw.Text(
              '${d.codPrestador} - ${d.nomePrestador}\n'
                  '${d.endereco} - ${d.bairro}\n'
                  '${d.cidade} - FONE: ${d.telefone}',
              style: _small,
            ),
            pw.SizedBox(height: 6),
            pw.Text('Especialização', style: _bold),
            pw.Text(d.especialidade, style: _small),
            pw.SizedBox(height: 6),
            pw.Text(
              (d.codigoVinculo.toString() == '30023') ? 'Vínculo:' : 'Vínculo via:',
              style: _bold,
            ),
            pw.Text(
              (d.codigoVinculo.toString() == '30023')
                  ? '${d.codigoVinculo} - ${d.nomeVinculo}'
                  : d.nomeVinculo,
              style: _small,
            ),
          ],
        ),
      ),
    ],
  );

  pw.Widget linhaTituloDireita() => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text('===================================================', style: _tiny),
      pw.Text('* Exija Letra Legível de seu Médico', style: _small),
    ],
  );

  pw.Widget blocoSegurado() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(children: [
        pw.Text('Segurado: ', style: _bold),
        pw.Expanded(child: pw.Text('${d.idMatricula} - ${d.nomeTitular}', style: _small)),
        pw.Text('Idade: ${d.idadePaciente}', style: _small),
      ]),
      pw.SizedBox(height: 4),
      pw.Row(children: [
        pw.Text('Dependente: ', style: _bold),
        pw.Expanded(
          child: pw.Text(
            '${d.idDependente} - ${d.idDependente != 0 ? d.nomePaciente : ''}',
            style: _small,
          ),
        ),
      ]),
      pw.SizedBox(height: 6),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Observações ', style: _bold),
        pw.Expanded(
          child: pw.Text(
            d.observacoes.isNotEmpty
                ? d.observacoes
                : 'AUTORIZAÇÃO EMITIDA PELO SISTEMA ASSISTWEB',
            style: _small,
          ),
        ),
      ]),
    ],
  );

  // Procedimentos: sem fundo cinza e sem “1” padrão
  pw.Widget procedimentos() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Text(
        'PROCEDIMENTOS AUTORIZADOS'
            '==========================================================',
        style: _small,
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        // Removido o 'color: PdfColors.grey300' para economizar toner
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: pw.Row(children: [
          pw.Expanded(
            flex: 75,
            child: pw.Text(
              d.procedimentos.isEmpty
                  ? ((d.codigoEspecialidade == 700)
                  ? '10021 - CONSULTA ODONTOLÓGICA'
                  : '10014 - CONSULTA MÉDICA')
                  : d.procedimentos.map((p) => '${p.codigo} - ${p.descricao}').join('  •  '),
              style: _small,
            ),
          ),
          // Quantidade: só exibe se houver exatamente 1 procedimento e quantidade > 0
          pw.Expanded(
            flex: 10,
            child: pw.Center(
              child: pw.Text(
                (d.procedimentos.length == 1 &&
                    (d.procedimentos.first.quantidade != null) &&
                    d.procedimentos.first.quantidade! > 0)
                    ? d.procedimentos.first.quantidade!.toString()
                    : '',
                style: _small,
              ),
            ),
          ),
          // Coparticipação (se existir)
          pw.Expanded(
            flex: 15,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                (d.percentual != null && d.percentual!.isNotEmpty)
                    ? '${d.percentual} % Copart'
                    : '',
                style: _small,
              ),
            ),
          ),
        ]),
      ),
    ],
  );

  pw.Widget usoSegurado() => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('================================================================', style: _tiny),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('USO DO SEGURADO', style: _bold)),
        pw.SizedBox(height: 6),
        pw.Text(
          'Autorizo o IPASEM a efetuar o pagamento dos serviços realizados e descontar a '
              'co-participação financeira devida desse valor, em meu vencimento mensal. '
              'Autorizo o serviço credenciado a fornecer cópia do meu prontuário à Auditoria Médica do IPASEM.',
          style: _small,
        ),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          pw.Expanded(child: pw.Text('Carimbo do Prestador')),
          pw.Text('Data: ___/___/______    Assinatura: ____________________________', style: _small),
        ]),
        pw.SizedBox(height: 6),
        pw.Text('================================================================', style: _tiny),
      ],
    ),
  );

  pw.Widget quadroOdonto() => pw.Container(
    margin: const pw.EdgeInsets.only(top: 10),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
    padding: const pw.EdgeInsets.all(6),
    child: pw.Column(
      children: [
        pw.Row(
          children: [
            pw.Expanded(child: pw.Text('PROCEDIMENTOS REALIZADOS', style: _bold)),
            pw.Text('Uso do Profissional'),
          ],
        ),
        linhaFina(),
        pw.Row(children: [
          pw.SizedBox(
              width: 150, child: pw.Text('Cod. Procediment\n\n.............................', style: _small)),
          pw.SizedBox(width: 100, child: pw.Text('Dente\n\n................', style: _small)),
          pw.SizedBox(width: 150, child: pw.Text('Faces\n\n...... ...... ...... ...... ......', style: _small)),
          pw.Expanded(
              child: pw.Text('Descrição do Procediment\n\n..............................................................',
                  style: _small)),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.SizedBox(
            width: 150,
            child: pw.Row(children: [
              pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(border: pw.Border.all())),
              pw.SizedBox(width: 6),
              pw.Text('RX em Anexo', style: _small),
            ]),
          ),
          pw.SizedBox(width: 100, child: pw.Text('Código:', style: _small)),
          pw.Expanded(child: pw.Text('Descrição:', style: _small)),
        ]),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          pw.Expanded(child: pw.Center(child: pw.Text('Data: ___/___/______', style: _small))),
          pw.Expanded(
              child: pw.Center(child: pw.Text('Carimbo e Assinatura: ____________________________', style: _small))),
        ])
      ],
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            header(),
            pw.SizedBox(height: 8),
            prestador(),
            pw.SizedBox(height: 8),
            linhaTituloDireita(),
            pw.SizedBox(height: 6),
            blocoSegurado(),
            pw.SizedBox(height: 6),
            pw.Text(aviso(), style: _small),
            pw.SizedBox(height: 10),
            procedimentos(),
            usoSegurado(),
            if (d.codigoEspecialidade == 700) quadroOdonto(),
          ],
        );
      },
    ),
  );

  return doc.save();
}
