class AutorizacaoResumo {
  final int numero;
  final String paciente;
  final String prestador;
  final String dataHora; // data_emissao + hora_emissao

  AutorizacaoResumo({
    required this.numero,
    required this.paciente,
    required this.prestador,
    required this.dataHora,
  });

  factory AutorizacaoResumo.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) => int.tryParse('${v ?? ''}') ?? 0;
    String s(dynamic v) => (v ?? '').toString().trim();
    final data = s(j['data_emissao']);
    final hora = s(j['hora_emissao']);
    final dataHora = (data.isNotEmpty && hora.isNotEmpty) ? '$data $hora' : (data.isNotEmpty ? data : '');

    return AutorizacaoResumo(
      numero:   toInt(j['nro_autorizacao']),
      paciente: s(j['nome_paciente']),
      prestador:s(j['nome_prestador_exec']),
      dataHora: dataHora,
    );
  }
}

class AutorizacaoDetalhe {
  final int numero;
  final String paciente;
  final String prestador;
  final String especialidade;
  final String dataEmissao; // data + hora se tiver
  final String endereco;
  final String bairro;
  final String cidade;
  final String telefone;
  final String? observacoes;

  AutorizacaoDetalhe({
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

  factory AutorizacaoDetalhe.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) => int.tryParse('${v ?? ''}') ?? 0;
    String s(dynamic v) => (v ?? '').toString().trim();
    final data = s(j['data_emissao']);
    final hora = s(j['hora_emissao']);
    final dataHora = (data.isNotEmpty && hora.isNotEmpty) ? '$data $hora' : (data.isNotEmpty ? data : '');

    return AutorizacaoDetalhe(
      numero:        toInt(j['nro_autorizacao']),
      paciente:      s(j['nome_paciente']),
      prestador:     s(j['nome_prestador_exec']),
      especialidade: s(j['nome_especialidade']),
      dataEmissao:   dataHora,
      endereco:      s(j['endereco_coml']),
      bairro:        s(j['bairro_coml']),
      cidade:        s(j['cidade_coml']),
      telefone:      s(j['telefone_coml']),
      observacoes:   (j['observacoes'] == null) ? null : s(j['observacoes']),
    );
  }
}
