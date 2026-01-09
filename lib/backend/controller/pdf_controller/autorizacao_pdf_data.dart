// lib/pdf/autorizacao_pdf_data.dart


import '../../../common/models/proc_item.dart';
import '../../../common/models/reimpressao.dart';

enum AutorizacaoTipo { medica, odontologica, exames, complementares }

class AutorizacaoPdfData {
  // --- tipo/layout ---
  final AutorizacaoTipo tipo;

  // --- metadados ---
  final int numero;
  final String dataEmissao;
  final String observacoes;
  final bool primeiraImpressao;

  // --- prestador execução / vínculo ---
  final String nomePrestador;
  final String codPrestador;
  final String especialidade;
  final String endereco;
  final String bairro;
  final String cidade;
  final String telefone;
  final String codigoVinculo;
  final String nomeVinculo;

  // --- segurado/paciente ---
  final int idMatricula;
  final String nomeTitular;
  final int idDependente;
  final String nomePaciente;
  final String idadePaciente;

  // --- procedimentos/coparticipação ---
  final List<ProcItem> procedimentos;
  final String? percentual;

  // --- NOVOS (opcionais) para exames/complementares ---
  final int? tipoAutorizacao;            // do backend (ex.: 2, 3, 7)
  final int? codSubtipoAutorizacao;      // do backend (ex.: 4)
  final String? operadorAlteracao;       // “Operador” no cabeçalho
  final String? nomePrestadorSolicitante;

  // --- também já existia no seu código ---
  final int codigoEspecialidade;

  AutorizacaoPdfData({
    required this.tipo,
    required this.numero,
    required this.nomePrestador,
    required this.codPrestador,
    required this.especialidade,
    required this.endereco,
    required this.bairro,
    required this.cidade,
    required this.telefone,
    required this.codigoVinculo,
    required this.nomeVinculo,
    required this.idMatricula,
    required this.nomeTitular,
    required this.idDependente,
    required this.nomePaciente,
    required this.idadePaciente,
    required this.dataEmissao,
    required this.codigoEspecialidade,
    required this.observacoes,
    required this.primeiraImpressao,
    required this.procedimentos,
    this.percentual,

    // novos
    this.tipoAutorizacao,
    this.codSubtipoAutorizacao,
    this.operadorAlteracao,
    this.nomePrestadorSolicitante,
  });

  /// Factory usada no app para montar PDFs de EXAMES (ou COMPLEMENTARES) a partir
  /// do detalhe retornado pela Reimpressão.
  factory AutorizacaoPdfData.fromReimpressaoExame({
    required ReimpressaoDetalhe det,
    required int idMatricula,
    List<ProcItem> procedimentos = const [],
  }) {
    final bool isComplementar =
        det.tipoAutorizacao == 3 && det.codSubtipoAutorizacao == 4;

    return AutorizacaoPdfData(
      tipo: isComplementar ? AutorizacaoTipo.complementares : AutorizacaoTipo.exames,
      numero: det.numero,

      // Prestador Execução
      nomePrestador: det.nomePrestadorExec,
      codPrestador: det.codConselhoExec,
      especialidade: det.nomeEspecialidade,
      endereco: det.enderecoComl,
      bairro: det.bairroComl,
      cidade: det.cidadeComl,
      telefone: det.telefoneComl,

      // Vínculo
      codigoVinculo: det.codVinculo,
      nomeVinculo: det.nomeVinculo,

      // Segurado/Paciente
      idMatricula: idMatricula,
      nomeTitular: det.nomeTitular.isEmpty ? '' : det.nomeTitular,
      idDependente: det.idDependente,
      nomePaciente: det.nomePaciente,
      idadePaciente: det.idadePaciente,

      // Metadados
      dataEmissao: det.dataEmissao,
      codigoEspecialidade: det.codEspecialidade,
      observacoes: det.observacoes,
      primeiraImpressao: false,

      // Procedimentos / copart
      percentual: det.percentual,
      procedimentos: procedimentos,

      // Novos (opcionais)
      tipoAutorizacao: det.tipoAutorizacao,
      codSubtipoAutorizacao: det.codSubtipoAutorizacao,
      operadorAlteracao: det.operadorAlteracao,
      nomePrestadorSolicitante: det.nomePrestadorSolicitante,
    );
  }
}
