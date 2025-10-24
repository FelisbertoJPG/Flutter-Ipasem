// lib/pdf/autorizacao_pdf_builders.dart
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'autorizacao_pdf_data.dart';

/// ========================= PUBLIC API =========================

Future<Uint8List> buildAutorizacaoExamesPdf(AutorizacaoPdfData d) async {
  final parts = await _CommonParts.create(d);
  parts._assertHasProcedures();
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => parts.pageExamesFisio(),
    ),
  );
  return doc.save();
}

Future<Uint8List> buildAutorizacaoExamesComplementaresPdf(AutorizacaoPdfData d) async {
  final parts = await _CommonParts.create(d);
  parts._assertHasProcedures();
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => parts.pageExamesComplementares(),
    ),
  );
  return doc.save();
}

Future<Uint8List> buildAutorizacaoMedicaPdf(AutorizacaoPdfData d) async {
  final parts = await _CommonParts.create(d);
  parts._assertHasProcedures();
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => parts.pageMedica(),
    ),
  );
  return doc.save();
}

Future<Uint8List> buildAutorizacaoOdontoPdf(AutorizacaoPdfData d) async {
  final parts = await _CommonParts.create(d);
  parts._assertHasProcedures();
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => parts.pageOdonto(),
    ),
  );
  return doc.save();
}

/// ========================= SHARED PARTS =========================

class _CommonParts {
  _CommonParts._(this.d, this.logo)
      : nowStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
        hojeStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

  final AutorizacaoPdfData d;
  final pw.ImageProvider? logo;
  final String nowStr;
  final String hojeStr;

  // estilos
  final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
  final small = const pw.TextStyle(fontSize: 10);
  final tiny  = const pw.TextStyle(fontSize: 9);

  static Future<_CommonParts> create(AutorizacaoPdfData d) async {
    pw.ImageProvider? _logo;
    try {
      final data = await rootBundle.load('assets/images/icons/logo_ipasem.png');
      _logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      _logo = null;
    }
    return _CommonParts._(d, _logo);
  }

  // --- validações ---
  void _assertHasProcedures() {
    if (d.procedimentos.isEmpty) {
      throw StateError('Nenhum procedimento informado para a autorização ${d.numero}.');
    }
  }

  // ---------- utils / helpers ----------
  pw.Widget _linha([PdfColor color = PdfColors.grey700]) =>
      pw.Container(margin: const pw.EdgeInsets.symmetric(vertical: 6), height: 1, color: color);

  pw.Widget _etiquetaOrigem() => pw.Container(
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

  String? get _operador {
    try {
      final v = (d as dynamic).operadorAlteracao as String?;
      final t = v?.trim() ?? '';
      return t.isEmpty ? null : t;
    } catch (_) {
      return null;
    }
  }

  String? get _solicitante {
    try {
      final v = (d as dynamic).nomePrestadorSolicitante as String?;
      final t = v?.trim() ?? '';
      return t.isEmpty ? null : t;
    } catch (_) {
      return null;
    }
  }

  // ---------- cabeçalhos ----------
  pw.Widget _header(String titulo) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(flex: 1, child: pw.Text('*** IPASEM N.H.***', style: small)),
      pw.SizedBox(width: 8),
      pw.Expanded(
        flex: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$hojeStr - $titulo${_operador != null ? ' - OPERADOR: $_operador' : ''}', style: bold),
            pw.SizedBox(height: 4),
            pw.Text('EMISSÃO: ${d.dataEmissao} | IMPRESSÃO: $nowStr', style: small),
            pw.SizedBox(height: 4),
            pw.Align(alignment: pw.Alignment.centerRight, child: _etiquetaOrigem()),
          ],
        ),
      ),
    ],
  );

  pw.Widget _linhaDireita() => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text('===================================================', style: tiny),
      pw.Text('* Exija Letra Legível de seu Médico', style: small),
    ],
  );

  pw.Widget _prestador({required bool showSolicitante}) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (logo != null)
        pw.Image(logo!, width: 140, height: 48, fit: pw.BoxFit.contain)
      else
        pw.Container(
          width: 140,
          height: 48,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600)),
          child: pw.Text('LOGO', style: tiny),
        ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Prestador de Serviços', style: bold),
            pw.Text(
              '${d.codPrestador} - ${d.nomePrestador}\n'
                  '${d.endereco} - ${d.bairro}\n'
                  '${d.cidade} - FONE: ${d.telefone}',
              style: small,
            ),
            if (showSolicitante && _solicitante != null) ...[
              pw.SizedBox(height: 8),
              pw.Text('Prestador Solicitante', style: bold),
              pw.Text(_solicitante!, style: small),
            ],
            pw.SizedBox(height: 6),
            pw.Text('Especialização', style: bold),
            pw.Text(d.especialidade, style: small),
            pw.SizedBox(height: 6),
            pw.Text((d.codigoVinculo.toString() == '30023') ? 'Vínculo:' : 'Vínculo via:', style: bold),
            pw.Text(
              (d.codigoVinculo.toString() == '30023')
                  ? '${d.codigoVinculo} - ${d.nomeVinculo}'
                  : d.nomeVinculo,
              style: small,
            ),
          ],
        ),
      ),
    ],
  );

  pw.Widget _blocoSegurado() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(children: [
        pw.Text('Segurado: ', style: bold),
        pw.Expanded(child: pw.Text('${d.idMatricula} - ${d.nomeTitular}', style: small)),
        pw.Text('Idade: ${d.idadePaciente}', style: small),
      ]),
      pw.SizedBox(height: 4),
      pw.Row(children: [
        pw.Text('Dependente: ', style: bold),
        pw.Expanded(
          child: pw.Text(
            '${d.idDependente} - ${d.idDependente != 0 ? d.nomePaciente : ''}',
            style: small,
          ),
        ),
      ]),
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start, // << corrigido
        children: [
          pw.Text('Observações ', style: bold),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              d.observacoes.isNotEmpty
                  ? d.observacoes.toUpperCase()
                  : 'AUTORIZAÇÃO EMITIDA PELO SISTEMA ASSISTWEB',
              style: small,
            ),
          ),
        ],
      ),
    ],
  );

  String _aviso() {
    if (d.tipo == AutorizacaoTipo.exames || d.tipo == AutorizacaoTipo.complementares) {
      return '* VALIDADE DE 30 DIAS A PARTIR DA DATA DE EMISSÃO!   * REALIZAR O EXAME SOMENTE COM A REQUISIÇÃO MÉDICA ORIGINAL.';
    }
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

  pw.Widget _procedimentosTabela({bool headerLinha = true}) {
    final itens = d.procedimentos; // já validado por _assertHasProcedures()

    pw.Widget rightCopart() => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        (d.percentual != null && d.percentual!.isNotEmpty) ? '${d.percentual} % Copart' : '',
        style: small,
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (headerLinha)
          pw.Text('PROCEDIMENTOS AUTORIZADOS==========================================================', style: small),
        if (headerLinha) pw.SizedBox(height: 6),
        pw.Container(
          color: PdfColors.grey300,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: pw.Column(
            children: [
              for (final p in itens)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 75, child: pw.Text('${p.codigo} - ${p.descricao}', style: small)),
                    pw.Expanded(
                      flex: 10,
                      child: pw.Center(child: pw.Text(p.quantidade > 0 ? '${p.quantidade}' : '', style: small)),
                    ),
                    pw.Expanded(flex: 15, child: rightCopart()),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _usoSegurado({bool withTopRule = true, bool withBottomRule = true}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (withTopRule) pw.Text('============================================================================', style: tiny),
        if (withTopRule) pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('USO DO SEGURADO', style: bold)),
        pw.SizedBox(height: 6),
        pw.Text(
          'Autorizo o IPASEM a efetuar o pagamento dos serviços realizados e descontar a '
              'co-participação financeira devida desse valor, em meu vencimento mensal. '
              'Autorizo o serviço credenciado a fornecer cópia do meu prontuário à Auditoria Médica do IPASEM.',
          style: small,
        ),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          pw.Expanded(child: pw.Text('Carimbo do Prestador', style: small)),
          pw.Text('Data: ___/___/______    Assinatura: ____________________________', style: small),
        ]),
        if (withBottomRule) pw.SizedBox(height: 6),
        if (withBottomRule) pw.Text('============================================================================', style: tiny),
      ],
    ),
  );

  // --------- bloco odontológico extra ---------
  pw.Widget _quadroOdonto() => pw.Container(
    margin: const pw.EdgeInsets.only(top: 10),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
    padding: const pw.EdgeInsets.all(6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(children: [
          pw.Expanded(child: pw.Text('PROCEDIMENTOS REALIZADOS', style: bold)),
          pw.Text('Uso do Profissional', style: small),
        ]),
        _linha(PdfColors.black),
        pw.Row(children: [
          pw.SizedBox(width: 150, child: pw.Text('Cod. Procediment\n\n.............................', style: small)),
          pw.SizedBox(width: 100, child: pw.Text('Dente\n\n................', style: small)),
          pw.SizedBox(width: 150, child: pw.Text('Faces\n\n...... ...... ...... ...... ......', style: small)),
          pw.Expanded(child: pw.Text('Descrição do Procediment\n\n..............................................................', style: small)),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.SizedBox(
            width: 150,
            child: pw.Row(children: [
              pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(border: pw.Border.all())),
              pw.SizedBox(width: 6),
              pw.Text('RX em Anexo', style: small),
            ]),
          ),
          pw.SizedBox(width: 100, child: pw.Text('Código:', style: small)),
          pw.Expanded(child: pw.Text('Descrição:', style: small)),
        ]),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          pw.Expanded(child: pw.Center(child: pw.Text('Data: ___/___/______', style: small))),
          pw.Expanded(child: pw.Center(child: pw.Text('Carimbo e Assinatura: ____________________________', style: small))),
        ])
      ],
    ),
  );

  // --------- subquadros de honorários (exames complementares) ---------
  pw.Widget _subQuadroHonorarios(String tituloEsq) {
    pw.Widget linhaCampo(String label) =>
        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Text(label.toUpperCase(), style: small));

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            linhaCampo(tituloEsq),
            linhaCampo('Código TUS:_________________________'),
            linhaCampo('Assinatura:_________________________'),
          ]),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            linhaCampo('CREMERS:_________________________'),
            linhaCampo(r'R$:_________________________'),
            linhaCampo('Total:_________________________'),
          ]),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            linhaCampo(r"CH's:_________________________"),
            linhaCampo(r'R$:_________________________'),
            linhaCampo('Total:_________________________'),
          ]),
        ),
      ],
    );
  }

  // ===================== PÁGINAS (sem fallback) =====================

  pw.Widget pageExamesFisio() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _header('AUTORIZAÇÃO DE EXAMES Nº: ${d.numero}'),
      pw.SizedBox(height: 8),
      _prestador(showSolicitante: true),
      pw.SizedBox(height: 8),
      _linhaDireita(),
      pw.SizedBox(height: 6),
      _blocoSegurado(),
      pw.SizedBox(height: 6),
      pw.Text(_aviso(), style: small),
      pw.SizedBox(height: 10),
      _procedimentosTabela(headerLinha: true),
      pw.SizedBox(height: 8),
      _usoSegurado(withTopRule: true, withBottomRule: true),
    ],
  );

  pw.Widget pageExamesComplementares() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _header('AUTORIZAÇÃO DE EXAMES Nº: ${d.numero}'),
      pw.SizedBox(height: 8),
      _prestador(showSolicitante: true),
      pw.SizedBox(height: 8),
      _linhaDireita(),
      pw.SizedBox(height: 6),
      _blocoSegurado(),
      pw.SizedBox(height: 6),
      pw.Text(_aviso(), style: small),
      pw.SizedBox(height: 10),

      pw.Text(
        '____________________PROCEDIMENTOS AUTORIZADOS__________________________________________________________________________'
            .toUpperCase(),
        style: small,
      ),
      pw.SizedBox(height: 8),
      _procedimentosTabela(headerLinha: false),
      pw.SizedBox(height: 12),

      pw.Text(
        '____________________HONORÁRIOS PROFISSIONAIS___________________________________________________USO DO IPASEM__________'
            .toUpperCase(),
        style: small,
      ),
      pw.SizedBox(height: 8),
      _subQuadroHonorarios('Cirurgião:_________________________'),
      _linha(PdfColors.black),
      _subQuadroHonorarios('Anestesista:_________________________'),
      _linha(PdfColors.black),
      _subQuadroHonorarios('Auxiliar:_________________________'),
      _linha(PdfColors.black),
      _subQuadroHonorarios('Outros:_________________________'),

      pw.SizedBox(height: 8),
      pw.Row(children: [
        pw.Expanded(
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('TOTAL DOS HONORÁRIOS PROFISSIONAIS:', style: small),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Text(r'R$:______________________________', style: small),
      ]),
      _linha(PdfColors.black),

      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(flex: 1, child: pw.Text('Carimbo do Prestador', style: small)),
        pw.SizedBox(width: 8),
        pw.Expanded(
          flex: 3,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Center(child: pw.Text('USO DO SEGURADO', style: bold)),
            pw.SizedBox(height: 6),
            pw.Text(
              'Autorizo o IPASEM a efetuar o pagamento dos serviços realizados e descontar a '
                  'coparticipação financeira devida desse valor, em meu vencimento mensal. '
                  'Autorizo o serviço credenciado a fornecer cópia do meu prontuário à Auditoria Médica do IPASEM.',
              style: small,
            ),
            pw.SizedBox(height: 10),
            pw.Text('Data: ___/___/______   Assinatura: ______________________________________', style: small),
          ]),
        ),
      ]),
    ],
  );

  pw.Widget pageMedica() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _header('AUTORIZAÇÃO Nº: ${d.numero}'),
      pw.SizedBox(height: 8),
      _prestador(showSolicitante: false),
      pw.SizedBox(height: 8),
      _linhaDireita(),
      pw.SizedBox(height: 6),
      _blocoSegurado(),
      pw.SizedBox(height: 6),
      pw.Text(_aviso(), style: small),
      pw.SizedBox(height: 10),
      _procedimentosTabela(headerLinha: true),
      _usoSegurado(withTopRule: true, withBottomRule: false),
    ],
  );

  pw.Widget pageOdonto() => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _header('AUTORIZAÇÃO ODONTOLÓGICA Nº: ${d.numero}'),
      pw.SizedBox(height: 8),
      _prestador(showSolicitante: false),
      pw.SizedBox(height: 8),
      _linhaDireita(),
      pw.SizedBox(height: 6),
      _blocoSegurado(),
      pw.SizedBox(height: 6),
      pw.Text(_aviso(), style: small),
      pw.SizedBox(height: 10),
      _procedimentosTabela(headerLinha: true),
      _usoSegurado(withTopRule: true, withBottomRule: false),
      _quadroOdonto(),
    ],
  );
}
