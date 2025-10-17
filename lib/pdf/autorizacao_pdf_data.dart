import '../models/proc_item.dart';
import '../models/reimpressao.dart'; // ReimpressaoDetalhe

// Enum deve ser top-level
enum AutorizacaoTipo { medica, odontologica, exames, complementares }

class AutorizacaoPdfData {
  final int numero;
  final AutorizacaoTipo tipo;

  // Prestador
  final String nomePrestador;
  final String codPrestador;
  final String especialidade;
  final String endereco;
  final String bairro;
  final String cidade;
  final String telefone;
  final String codigoVinculo;
  final String nomeVinculo;

  // Segurado/Paciente
  final int idMatricula;
  final String nomeTitular;
  final int idDependente;
  final String nomePaciente;
  final String idadePaciente;

  // Metadados
  final String dataEmissao;       // “dd/MM/yyyy” (pode vir com hora)
  final int codigoEspecialidade;
  final String observacoes;
  final String? percentual;
  final bool primeiraImpressao;

  final List<ProcItem> procedimentos;

  const AutorizacaoPdfData({
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
    this.percentual,
    this.primeiraImpressao = false,
    this.procedimentos = const [],
  });

  factory AutorizacaoPdfData.fromReimpressaoExame({
    required ReimpressaoDetalhe det,
    required int idMatricula,
    List<ProcItem> procedimentos = const [],
  }) {
    final tipo = (det.tipoAutorizacao == 3 && det.codSubtipoAutorizacao == 4)
        ? AutorizacaoTipo.complementares
        : AutorizacaoTipo.exames;

    return AutorizacaoPdfData(
      tipo: tipo,
      numero: det.numero,
      dataEmissao: det.dataEmissao,
      codigoEspecialidade: det.codEspecialidade,
      // Prestador
      codPrestador: det.codConselhoExec,
      nomePrestador: det.nomePrestadorExec,
      endereco: det.enderecoComl,
      bairro: det.bairroComl,
      cidade: det.cidadeComl,
      telefone: det.telefoneComl,
      // Especialidade / vínculo
      especialidade: det.nomeEspecialidade,
      codigoVinculo: det.codVinculo,
      nomeVinculo: det.nomeVinculo,
      // Segurado
      idMatricula: idMatricula,
      nomeTitular: det.nomeTitular,
      idadePaciente: det.idadePaciente,
      idDependente: det.idDependente,
      nomePaciente: det.nomePaciente,
      // Observações / proc / copart
      observacoes: det.observacoes,
      procedimentos: procedimentos,
      percentual: det.percentual,
      primeiraImpressao: false,
    );
  }
}
