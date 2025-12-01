// lib/models/reimpressao.dart

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

  factory ReimpressaoResumo.fromMap(Map<String, dynamic> m) {
    int toInt(dynamic v) => int.tryParse('${v ?? ''}') ?? 0;
    String s(dynamic v) => (v ?? '').toString();

    return ReimpressaoResumo(
      numero:        toInt(m['nro_autorizacao'] ?? m['numero']),
      titular:       s(m['nome_titular'] ?? m['titular']),
      paciente:      s(m['nome_paciente'] ?? m['paciente']),
      prestadorExec: s(m['nome_prestador_exec'] ?? m['prestador_exec']),
      dataEmissao:   s(m['data_emissao']),
      horaEmissao:   s(m['hora_emissao']),
      observacoes:   s(m['observacoes']),
    );
  }

  factory ReimpressaoResumo.fromJson(Map<String, dynamic> j) =>
      ReimpressaoResumo.fromMap(j);
}

/// Detalhe completo para montar o PDF no app
class ReimpressaoDetalhe {
  final int numero;

  // Classificação (podem não vir => null)
  final int? tipoAutorizacao;           // 2=exames, 7=fisio, 3 e sub=4 = complementares
  final int? codSubtipoAutorizacao;     // 4 = complementares

  // Paciente / titular
  final String nomePaciente;
  final String nomeTitular;             // pode vir vazio
  final int idDependente;
  final String idadePaciente;           // “52”, “10”, etc. (string mesmo)

  // Prestador de execução
  final String nomePrestadorExec;
  final String codConselhoExec;

  // Especialidade
  final String nomeEspecialidade;
  final int codEspecialidade;

  // Endereço comercial
  final String enderecoComl;
  final String bairroComl;
  final String cidadeComl;
  final String telefoneComl;

  // Vínculo
  final String codVinculo;
  final String nomeVinculo;

  // Metadados
  final String observacoes;
  final String dataEmissao;             // já concatena hora se existir
  final String? percentual;             // “perc_cobertura”, “percentual” etc.

  // Opcionais
  final String? nomePrestadorSolicitante;
  final String? operadorAlteracao;

  ReimpressaoDetalhe({
    required this.numero,
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
    this.tipoAutorizacao,
    this.codSubtipoAutorizacao,
    this.percentual,
    this.nomePrestadorSolicitante,
    this.operadorAlteracao,
  });

  factory ReimpressaoDetalhe.fromMap(Map<String, dynamic> m) {
    int? i(dynamic v) => v == null ? null : int.tryParse('$v');
    int i0(dynamic v) => int.tryParse('${v ?? ''}') ?? 0;
    String s(dynamic v) => (v ?? '').toString().trim();

    // data + hora (se houver)
    final data = s(m['data_emissao']);
    final hora = s(m['hora_emissao']);
    final dataEmissao = (data.isNotEmpty && hora.isNotEmpty) ? '$data $hora' : data;

    // percentual pode vir em chaves diferentes
    String? _percentual() {
      final p = s(m['percentual']);
      final p2 = s(m['perc_cobertura'] ?? m['o_perc_cobertura']);
      final val = (p.isNotEmpty ? p : (p2.isNotEmpty ? p2 : ''));
      return val.isEmpty ? null : val;
    }

    String? _opt(dynamic v) {
      final t = s(v);
      return t.isEmpty ? null : t;
    }

    return ReimpressaoDetalhe(
      numero:                 i0(m['numero'] ?? m['nro_autorizacao']),
      tipoAutorizacao:        i(m['tipo_autorizacao'] ?? m['tipoAutorizacao'] ?? m['tipo']),
      codSubtipoAutorizacao:  i(m['codsubtipo_autorizacao'] ?? m['cod_subtipo_autorizacao'] ?? m['cod_subtipo']),
      nomePaciente:           s(m['nome_paciente']),
      nomeTitular:            s(m['nome_titular']),
      idDependente:           i0(m['iddependente']),
      idadePaciente:          s(m['idade_paciente']),
      nomePrestadorExec:      s(m['nome_prestador_exec'] ?? m['nome_prestador']),
      codConselhoExec:        s(m['cod_conselho_exec'] ?? m['cod_conselho']),
      nomeEspecialidade:      s(m['nome_especialidade']),
      codEspecialidade:       i0(m['cod_especialidade'] ?? m['codesp'] ?? m['codigo_especialidade']),
      enderecoComl:           s(m['endereco_coml']),
      bairroComl:             s(m['bairro_coml']),
      cidadeComl:             s(m['cidade_coml']),
      telefoneComl:           s(m['telefone_coml']),
      codVinculo:             s(m['cod_vinculo']),
      nomeVinculo:            s(m['nome_vinculo']),
      observacoes:            s(m['observacoes']),
      dataEmissao:            dataEmissao,
      percentual:             _percentual(),
      nomePrestadorSolicitante: _opt(m['nome_prestador_solicitante'] ?? m['nome_prestador_sol']),
      operadorAlteracao:        _opt(m['operador_alteracao'] ?? m['operador'] ?? m['operadorAlteracao']),
    );
  }

  // Alias para compatibilidade (se algum ponto do app ainda usa `fromJson`)
  factory ReimpressaoDetalhe.fromJson(Map<String, dynamic> j) =>
      ReimpressaoDetalhe.fromMap(j);
}
