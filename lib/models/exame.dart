// lib/models/exame.dart

class ExameResumo {
  final int numero;
  final String paciente;   // nome_dependente
  final String prestador;  // nome_prestador
  final String dataHora;   // data_emissao + hora_emissao
  /// Status: 'P' = pendente, 'A' = liberada/auditada, 'R' = reimpressão (ou outros).
  final String? status;

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
    final dataHora = (data.isNotEmpty && hora.isNotEmpty)
        ? '$data $hora'
        : (data.isNotEmpty ? data : '');

    // Aceita múltiplas origens para o status
    String statusOf(Map<String, dynamic> m) {
      final candidates = ['auditado', 'status', 'situacao', 'SITUACAO', 'AUDITADO', 'STATUS'];
      for (final k in candidates) {
        if (m.containsKey(k)) return s(m[k]).toUpperCase();
      }
      return '';
    }

    return ExameResumo(
      numero:   toInt(j['nro_autorizacao'] ?? j['NRO_AUTORIZACAO'] ?? j['numero'] ?? j['NUMERO']),
      paciente: s(j['nome_dependente'] ?? j['nome_paciente'] ?? j['NOME_DEPENDENTE'] ?? j['NOME_PACIENTE']),
      prestador:s(j['nome_prestador'] ?? j['nome_prestador_exec'] ?? j['NOME_PRESTADOR'] ?? j['NOME_PRESTADOR_EXEC']),
      dataHora: dataHora,
      status:   statusOf(j),
    );
  }

  String get _st => (status ?? '').trim().toUpperCase();
  bool get isPendente   => _st == 'P';
  bool get isLiberada   => _st == 'A';
  bool get isReimpressao=> _st == 'R';
}

class ExameDetalhe {
  final int numero;
  final String paciente;
  final String prestador;
  final String especialidade;
  final String dataEmissao; // pode vir só a data
  final String endereco;
  final String bairro;
  final String cidade;
  final String telefone;
  final String? observacoes;

  const ExameDetalhe({
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

  factory ExameDetalhe.fromJson(Map<String, dynamic> j) {
    String _s(dynamic v) => (v ?? '').toString().trim();

    String pick(Iterable<String> keys) {
      for (final k in keys) {
        if (j.containsKey(k)) {
          final v = _s(j[k]);
          if (v.isNotEmpty) return v;
        }
      }
      return '';
    }

    int pickInt(Iterable<String> keys) {
      for (final k in keys) {
        if (j.containsKey(k)) {
          final v = _s(j[k]);
          if (v.isNotEmpty) {
            final n = int.tryParse(v);
            if (n != null) return n;
          }
        }
      }
      return 0;
    }

    final numero      = pickInt(['nro_autorizacao','numero','NRO_AUTORIZACAO','NUMERO']);
    final paciente    = pick(['nome_dependente','nome_paciente','NOME_DEPENDENTE','NOME_PACIENTE']);
    final prestador   = pick(['nome_prestador','nome_prestador_exec','NOME_PRESTADOR','NOME_PRESTADOR_EXEC']);
    final especialid  = pick(['nome_especialidade','NOME_ESPECIALIDADE']);

    final data        = pick(['data_emissao','DATA_EMISSAO']);
    final hora        = pick(['hora_emissao','HORA_EMISSAO']);
    final dataEmissao = (data.isNotEmpty && hora.isNotEmpty) ? '$data $hora' : data;

    final endereco    = pick(['endereco_coml','ENDERECO_COML','endereco','ENDERECO']);
    final bairro      = pick(['bairro_coml','BAIRRO_COML','bairro','BAIRRO']);
    final cidade      = pick(['cidade_coml','CIDADE_COML','cidade','CIDADE']);
    final telefone    = pick(['telefone_coml','TELEFONE_COML','telefone','TELEFONE']);
    final observ      = pick(['observacoes','OBSERVACOES']);

    return ExameDetalhe(
      numero:        numero,
      paciente:      paciente,
      prestador:     prestador,
      especialidade: especialid,
      dataEmissao:   dataEmissao,
      endereco:      endereco,
      bairro:        bairro,
      cidade:        cidade,
      telefone:      telefone,
      observacoes:   observ.isEmpty ? null : observ,
    );
  }

  /// Sinaliza se o JSON trouxe algo útil (para não exibir botão com tudo vazio).
  bool get hasCoreInfo =>
      prestador.isNotEmpty ||
          paciente.isNotEmpty ||
          especialidade.isNotEmpty ||
          dataEmissao.isNotEmpty;
}