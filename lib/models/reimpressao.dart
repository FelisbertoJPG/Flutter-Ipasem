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

class ReimpressaoDetalhe {
  final int numero;
  final String nomePaciente;
  final String nomePrestadorExec;
  final String nomeEspecialidade;
  final String dataEmissao;
  final String enderecoComl;
  final String bairroComl;
  final String cidadeComl;
  final String telefoneComl;
  final String observacoes;

  ReimpressaoDetalhe({
    required this.numero,
    required this.nomePaciente,
    required this.nomePrestadorExec,
    required this.nomeEspecialidade,
    required this.dataEmissao,
    required this.enderecoComl,
    required this.bairroComl,
    required this.cidadeComl,
    required this.telefoneComl,
    required this.observacoes,
  });

  factory ReimpressaoDetalhe.fromMap(Map<String, dynamic> m) => ReimpressaoDetalhe(
    numero:            (m['numero'] ?? m['nro_autorizacao'] ?? 0) as int,
    nomePaciente:      (m['nome_paciente'] ?? '').toString(),
    nomePrestadorExec: (m['nome_prestador_exec'] ?? '').toString(),
    nomeEspecialidade: (m['nome_especialidade'] ?? '').toString(),
    dataEmissao:       (m['data_emissao'] ?? '').toString(),
    enderecoComl:      (m['endereco_coml'] ?? '').toString(),
    bairroComl:        (m['bairro_coml'] ?? '').toString(),
    cidadeComl:        (m['cidade_coml'] ?? '').toString(),
    telefoneComl:      (m['telefone_coml'] ?? '').toString(),
    observacoes:       (m['observacoes'] ?? '').toString(),
  );
}
