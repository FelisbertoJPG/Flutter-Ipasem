import '../models/proc_item.dart';

class AutorizacaoPdfData {
  final int numero;

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
  final int idMatricula;        // p/ “6542 - NOME”
  final String nomeTitular;     // p/ “Segurado”
  final int idDependente;       // p/ “Dependente”
  final String nomePaciente;    // idem
  final String idadePaciente;   // string pronta (“10”, “52”)

  // Metadados
  final String dataEmissao;         // “dd/MM/yyyy”
  final int codigoEspecialidade;    // p/ regra dos avisos
  final String observacoes;
  final String? percentual;         // ex.: “30”
  final bool primeiraImpressao;

  final List<ProcItem> procedimentos;

  const AutorizacaoPdfData({
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
    this.percentual,
    this.procedimentos = const [],
  });
}
