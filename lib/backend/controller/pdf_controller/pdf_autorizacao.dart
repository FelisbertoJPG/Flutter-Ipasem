//lib/backend/controller/pdf_controller/pdf_autorizacao.dart
import '../../../common/models/proc_item.dart';
import '../../../common/models/reimpressao.dart';
import 'autorizacao_pdf_data.dart';


List<ProcItem> _extractProcedures(Map<String, dynamic> payload) {
  final data = (payload['data'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  final procs = (data['procedimentos_autorizados'] as List?) ??
      (data['procedimentos'] as List?) ??
      (payload['procedimentos_autorizados'] as List?) ??
      const <dynamic>[];

  return procs
      .whereType<Map>()
      .map((e) => ProcItem.fromMap(e.cast<String, dynamic>()))
      .toList(growable: false);
}

bool _isExamesOuComplementares(ReimpressaoDetalhe d) {
  final t = d.tipoAutorizacao ?? 0;
  final sub = d.codSubtipoAutorizacao ?? 0;
  return t == 2 || t == 7 || (t == 3 && sub == 4);
}

AutorizacaoPdfData montarPdfDataDeReimpressao({
  required ReimpressaoDetalhe detalhe,
  required int idMatricula,
  required Map<String, dynamic> payload,
}) {
  final itens = _extractProcedures(payload);
  if (itens.isEmpty) {
    throw StateError('Nenhum procedimento informado para a autorização ${detalhe.numero}.');
  }

  final tipo = (() {
    if (_isExamesOuComplementares(detalhe)) {
      if (detalhe.tipoAutorizacao == 3 && detalhe.codSubtipoAutorizacao == 4) {
        return AutorizacaoTipo.complementares;
      }
      return AutorizacaoTipo.exames;
    }
    return (detalhe.codEspecialidade == 700)
        ? AutorizacaoTipo.odontologica
        : AutorizacaoTipo.medica;
  })();

  return AutorizacaoPdfData(
    tipo: tipo,
    numero: detalhe.numero,
    // prestador execução
    nomePrestador: detalhe.nomePrestadorExec, // ajuste se seu model usa outro nome
    codPrestador: detalhe.codConselhoExec ?? '',
    especialidade: detalhe.nomeEspecialidade,
    endereco: detalhe.enderecoComl,
    bairro: detalhe.bairroComl,
    cidade: detalhe.cidadeComl,
    telefone: detalhe.telefoneComl,
    // vínculo
    codigoVinculo: detalhe.codVinculo ?? '',
    nomeVinculo: detalhe.nomeVinculo ?? '',
    // segurado
    idMatricula: idMatricula,
    nomeTitular: detalhe.nomeTitular,
    idDependente: detalhe.idDependente,
    nomePaciente: detalhe.nomePaciente,
    idadePaciente: detalhe.idadePaciente,
    // metadados
    dataEmissao: detalhe.dataEmissao,
    codigoEspecialidade: detalhe.codEspecialidade,
    observacoes: detalhe.observacoes ?? '',
    primeiraImpressao: false,
    // procs
    procedimentos: itens,
    percentual: detalhe.percentual,
    // extras
    tipoAutorizacao: detalhe.tipoAutorizacao,
    codSubtipoAutorizacao: detalhe.codSubtipoAutorizacao,
    operadorAlteracao: detalhe.operadorAlteracao,
    nomePrestadorSolicitante: detalhe.nomePrestadorSolicitante,
  );
}
