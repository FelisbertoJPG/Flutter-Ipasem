class ReimpressaoResumo {
  final int numero;
  final String titular;
  final String paciente;
  final String prestadorExec;
  final String dataEmissao;
  final String horaEmissao;
  final String observacoes;

  ReimpressaoResumo({
    required this.numero,
    required this.titular,
    required this.paciente,
    required this.prestadorExec,
    required this.dataEmissao,
    required this.horaEmissao,
    required this.observacoes,
  });

  factory ReimpressaoResumo.fromMap(Map<String, dynamic> m) => ReimpressaoResumo(
    numero:        (m['nro_autorizacao'] ?? m['numero'] ?? 0) as int,
    titular:       (m['nome_titular'] ?? m['titular'] ?? '').toString(),
    paciente:      (m['nome_paciente'] ?? m['paciente'] ?? '').toString(),
    prestadorExec: (m['nome_prestador_exec'] ?? m['prestador_exec'] ?? '').toString(),
    dataEmissao:   (m['data_emissao'] ?? '').toString(),
    horaEmissao:   (m['hora_emissao'] ?? '').toString(),
    observacoes:   (m['observacoes'] ?? '').toString(),
  );
}

/// Detalhe completo para montar o PDF no app
class ReimpressaoDetalhe {
  final int numero;

  // mapeados dos seus endpoints (api-dev.php -> reimpressao_detalhe)
  final int tipoAutorizacao;            // tipo_autorizacao
  final int codSubtipoAutorizacao;      // codsubtipo_autorizacao

  final String nomePaciente;            // nome_paciente
  final String nomeTitular;             // nome_titular (pode vir vazio; fallback: profile.nome)
  final int idDependente;               // iddependente
  final String idadePaciente;           // idade_paciente (texto “52” ou “10”)

  final String nomePrestadorExec;       // nome_prestador_exec
  final String codConselhoExec;         // cod_conselho_exec

  final String nomeEspecialidade;       // nome_especialidade
  final int codEspecialidade;           // cod_especialidade

  final String enderecoComl;            // endereco_coml
  final String bairroComl;              // bairro_coml
  final String cidadeComl;              // cidade_coml
  final String telefoneComl;            // telefone_coml

  final String codVinculo;              // cod_vinculo
  final String nomeVinculo;             // nome_vinculo

  final String observacoes;             // observacoes
  final String dataEmissao;             // data_emissao (já vem "dd/MM/yyyy" na sua API v1)
  final String? percentual;             // percentual (pode não vir → null)

  // opcionais / não usados no layout médico básico, mas úteis no futuro
  final String? nomePrestadorSolicitante; // nome_prestador_sol
  final String? operadorAlteracao;        // operador_alteracao

  ReimpressaoDetalhe({
    required this.numero,
    required this.tipoAutorizacao,
    required this.codSubtipoAutorizacao,
    required this.nomePaciente,
    required this.nomeTitular,
    required this.idDependente,
    required this.idadePaciente,
    required this.nomePrestadorExec,
    required this.codConselhoExec,
    required this.nomeEspecialidade,
    required this.codEspecialidade,
    required this.enderecoComl,
    required this.bairroComl,
    required this.cidadeComl,
    required this.telefoneComl,
    required this.codVinculo,
    required this.nomeVinculo,
    required this.observacoes,
    required this.dataEmissao,
    this.percentual,
    this.nomePrestadorSolicitante,
    this.operadorAlteracao,
  });

  factory ReimpressaoDetalhe.fromMap(Map<String, dynamic> m) => ReimpressaoDetalhe(
    numero:                 (m['numero'] ?? m['nro_autorizacao'] ?? 0) as int,
    tipoAutorizacao:        int.tryParse((m['tipo_autorizacao'] ?? '0').toString()) ?? 0,
    codSubtipoAutorizacao:  int.tryParse((m['codsubtipo_autorizacao'] ?? '0').toString()) ?? 0,
    nomePaciente:           (m['nome_paciente'] ?? '').toString(),
    nomeTitular:            (m['nome_titular'] ?? '').toString(),
    idDependente:           int.tryParse((m['iddependente'] ?? '0').toString()) ?? 0,
    idadePaciente:          (m['idade_paciente'] ?? '').toString(),
    nomePrestadorExec:      (m['nome_prestador_exec'] ?? '').toString(),
    codConselhoExec:        (m['cod_conselho_exec'] ?? '').toString(),
    nomeEspecialidade:      (m['nome_especialidade'] ?? '').toString(),
    codEspecialidade:       int.tryParse((m['cod_especialidade'] ?? '0').toString()) ?? 0,
    enderecoComl:           (m['endereco_coml'] ?? '').toString(),
    bairroComl:             (m['bairro_coml'] ?? '').toString(),
    cidadeComl:             (m['cidade_coml'] ?? '').toString(),
    telefoneComl:           (m['telefone_coml'] ?? '').toString(),
    codVinculo:             (m['cod_vinculo'] ?? '').toString(),
    nomeVinculo:            (m['nome_vinculo'] ?? '').toString(),
    observacoes:            (m['observacoes'] ?? '').toString(),
    dataEmissao:            (m['data_emissao'] ?? '').toString(),
    percentual:             (m['percentual']?.toString().trim().isEmpty ?? true) ? null : m['percentual'].toString(),
    nomePrestadorSolicitante: (m['nome_prestador_sol'] ?? '').toString().trim().isEmpty ? null : (m['nome_prestador_sol'] ?? '').toString(),
    operadorAlteracao:        (m['operador_alteracao'] ?? '').toString().trim().isEmpty ? null : (m['operador_alteracao'] ?? '').toString(),
  );
}
