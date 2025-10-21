class ExameResumo {
  final int numero;
  final String paciente;   // nome_dependente
  final String prestador;  // nome_prestador
  final String dataHora;   // data_emissao + hora_emissao
  final String? status;    // auditado: 'P' pendente, etc.

  ExameResumo({
    required this.numero,
    required this.paciente,
    required this.prestador,
    required this.dataHora,
    this.status,
  });

  factory ExameResumo.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) => int.tryParse('${v ?? ''}') ?? 0;
    String s(dynamic v) => (v ?? '').toString().trim();

    final data = s(j['data_emissao']);
    final hora = s(j['hora_emissao']);
    final dataHora =
    (data.isNotEmpty && hora.isNotEmpty) ? '$data $hora' : (data.isNotEmpty ? data : '');

    return ExameResumo(
      numero:   toInt(j['nro_autorizacao']),
      paciente: s(j['nome_dependente'] ?? j['nome_paciente']),
      prestador:s(j['nome_prestador'] ?? j['nome_prestador_exec']),
      dataHora: dataHora,
      status:   s(j['auditado']),
    );
  }
}

class ExameDetalhe {
  final int numero;
  final String paciente;
  final String prestador;
  final String especialidade;
  final String dataEmissao; // pode vir só data; concatenei se tiver hora
  final String endereco;
  final String bairro;
  final String cidade;
  final String telefone;
  final String? observacoes;

  ExameDetalhe({
    required this.numero,
    required this.paciente,
    required this.prestador,
    required this.especialidade,
    required this.dataEmissao,
    required this.endereco,
    required this.bairro,
    required this.cidade,
    required this.telefone,
    this.observacoes,
  });

  // `exame_consulta` usa o mesmo SP de detalhes do site,
  // então os nomes aqui são iguais aos de autorização “geral”.
  factory ExameDetalhe.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) => int.tryParse('${v ?? ''}') ?? 0;
    String s(dynamic v) => (v ?? '').toString().trim();

    final data = s(j['data_emissao']);
    final hora = s(j['hora_emissao']);
    final dataEmissao =
    (data.isNotEmpty && hora.isNotEmpty) ? '$data $hora' : (data.isNotEmpty ? data : '');

    return ExameDetalhe(
      numero:        toInt(j['nro_autorizacao'] ?? j['numero']),
      paciente:      s(j['nome_paciente'] ?? j['nome_dependente']),
      prestador:     s(j['nome_prestador_exec'] ?? j['nome_prestador']),
      especialidade: s(j['nome_especialidade'] ?? ''),
      dataEmissao:   dataEmissao,
      endereco:      s(j['endereco_coml'] ?? ''),
      bairro:        s(j['bairro_coml'] ?? ''),
      cidade:        s(j['cidade_coml'] ?? ''),
      telefone:      s(j['telefone_coml'] ?? ''),
      observacoes:   j['observacoes'] == null ? null : s(j['observacoes']),
    );
  }
}