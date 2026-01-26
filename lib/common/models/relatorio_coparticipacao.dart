// lib/models/relatorio_coparticipacao.dart
//
// Modelos para o endpoint: relatorio/coparticipacao
// JSON esperado (exemplo):
// {
//   "ok": true,
//   "data": {
//     "periodo": {
//       "entrada": {"data_inicio":"11/2025","data_fim":"11/2025"},
//       "efetivo": {"ano_inicio":2025,"mes_inicio":9,"ano_fim":2025,"mes_fim":9}
//     },
//     "usuario": {"idmatricula": 123, "nome_titular": "Fulano"},
//     "extratos": [...],
//     "totais": {...},
//     "totaisPagos": {"totalpago": 0, "valortotal": 0},
//     "copar": [{"tipo_caixa": 1, "total": 123.45}]
//   },
//   "meta": {"eid": "..."},
//   "error": null
// }

import 'dart:convert';

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  if (v is bool) return v ? 1 : 0;
  return null;
}

/// Converte strings monetárias no formato brasileiro "1.234,56"
/// e também aceita números ou strings com ponto decimal.
double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    // Tenta parse direto
    final direct = double.tryParse(s);
    if (direct != null) return direct;
    // Normaliza brasileiro: remove separador de milhar '.' e troca ',' por '.'
    final normalized = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }
  if (v is bool) return v ? 1.0 : 0.0;
  return null;
}

/// Normaliza timestamps para **segundos**.
/// Se vier em ms (muito grande), converte para s.
int? _asEpochSec(dynamic v) {
  final n = _asInt(v);
  if (n == null) return null;
  return (n > 20000000000) ? (n ~/ 1000) : n;
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    return s == '1' || s == 'true' || s == 'yes' || s == 'y' || s == 'on';
  }
  return false;
}

/// --------------------------- Top-level response ---------------------------

class RelatorioResponse {
  final bool ok;
  final RelatorioCoparticipacaoData? data;
  final Map<String, dynamic>? meta;
  final RelatorioError? error;

  RelatorioResponse({
    required this.ok,
    this.data,
    this.meta,
    this.error,
  });

  factory RelatorioResponse.fromMap(Map<String, dynamic> m) => RelatorioResponse(
    ok: _asBool(m['ok']),
    data: m['data'] is Map<String, dynamic>
        ? RelatorioCoparticipacaoData.fromMap(
      m['data'] as Map<String, dynamic>,
    )
        : null,
    meta: m['meta'] is Map<String, dynamic>
        ? (m['meta'] as Map<String, dynamic>)
        : null,
    error: m['error'] is Map<String, dynamic>
        ? RelatorioError.fromMap(m['error'] as Map<String, dynamic>)
        : null,
  );

  static RelatorioResponse fromJson(String s) =>
      RelatorioResponse.fromMap(json.decode(s) as Map<String, dynamic>);
}

class RelatorioError {
  final String? eid;
  final String? code;
  final String? message;

  RelatorioError({
    this.eid,
    this.code,
    this.message,
  });

  /// Hoje o backend manda:
  /// {
  ///   ok: false,
  ///   data: null,
  ///   meta: { eid: '...' },
  ///   error: { code: 'X', message: 'Y', details: ... }
  /// }
  ///
  /// Aqui estamos mapeando apenas o objeto `error` em si.
  /// Se quiser o EID, você já tem em `RelatorioResponse.meta['eid']`.
  factory RelatorioError.fromMap(Map<String, dynamic> m) => RelatorioError(
    eid: m['eid']?.toString(), // pode vir vazio no padrão atual
    code: m['code']?.toString(),
    message: m['message']?.toString(),
  );
}

/// --------------------------- Payload principal ----------------------------

class RelatorioCoparticipacaoData {
  final RelatorioPeriodo periodo;
  final RelatorioUsuario? usuario;
  final List<ExtratoItem> extratos;
  final RelatorioTotais totais;
  final RelatorioTotaisPagos totaisPagos;
  final List<RelatorioCoparItem> copar;

  RelatorioCoparticipacaoData({
    required this.periodo,
    required this.usuario,
    required this.extratos,
    required this.totais,
    required this.totaisPagos,
    required this.copar,
  });

  factory RelatorioCoparticipacaoData.fromMap(Map<String, dynamic> m) =>
      RelatorioCoparticipacaoData(
        periodo: RelatorioPeriodo.fromMap(
          (m['periodo'] ?? const {}) as Map<String, dynamic>,
        ),
        usuario: m['usuario'] is Map<String, dynamic>
            ? RelatorioUsuario.fromMap(m['usuario'] as Map<String, dynamic>)
            : null,
        extratos: (m['extratos'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ExtratoItem.fromMap)
            .toList(),
        totais: RelatorioTotais.fromMap(
          (m['totais'] ?? const {}) as Map<String, dynamic>,
        ),
        totaisPagos: RelatorioTotaisPagos.fromMap(
          (m['totaisPagos'] ?? const {}) as Map<String, dynamic>,
        ),
        copar: (m['copar'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RelatorioCoparItem.fromMap)
            .toList(),
      );

  bool get isEmpty =>
      extratos.isEmpty &&
          copar.isEmpty &&
          totais.A_saldoMesesAnteriores == 0 &&
          totais.B_totalCoparticipacao == 0 &&
          totais.C_debitosAvulsos == 0 &&
          totais.D_descontadoCopart == 0 &&
          totais.E_creditosAvulsos == 0;
}

/// --------------------------- Período/Usuário ------------------------------

class RelatorioPeriodo {
  final RelatorioPeriodoEntrada entrada;
  final RelatorioPeriodoEfetivo efetivo;

  RelatorioPeriodo({
    required this.entrada,
    required this.efetivo,
  });

  factory RelatorioPeriodo.fromMap(Map<String, dynamic> m) => RelatorioPeriodo(
    entrada: RelatorioPeriodoEntrada.fromMap(
      (m['entrada'] ?? const {}) as Map<String, dynamic>,
    ),
    efetivo: RelatorioPeriodoEfetivo.fromMap(
      (m['efetivo'] ?? const {}) as Map<String, dynamic>,
    ),
  );
}

class RelatorioPeriodoEntrada {
  final String? dataInicio; // "MM/YYYY"
  final String? dataFim; // "MM/YYYY"

  RelatorioPeriodoEntrada({
    this.dataInicio,
    this.dataFim,
  });

  factory RelatorioPeriodoEntrada.fromMap(Map<String, dynamic> m) =>
      RelatorioPeriodoEntrada(
        dataInicio: m['data_inicio']?.toString(),
        dataFim: m['data_fim']?.toString(),
      );
}

class RelatorioPeriodoEfetivo {
  final int? anoInicio;
  final int? mesInicio;
  final int? anoFim;
  final int? mesFim;

  RelatorioPeriodoEfetivo({
    this.anoInicio,
    this.mesInicio,
    this.anoFim,
    this.mesFim,
  });

  factory RelatorioPeriodoEfetivo.fromMap(Map<String, dynamic> m) =>
      RelatorioPeriodoEfetivo(
        anoInicio: _asInt(m['ano_inicio']),
        mesInicio: _asInt(m['mes_inicio']),
        anoFim: _asInt(m['ano_fim']),
        mesFim: _asInt(m['mes_fim']),
      );
}

class RelatorioUsuario {
  final int? idmatricula;
  final String? nomeTitular;

  RelatorioUsuario({
    this.idmatricula,
    this.nomeTitular,
  });

  factory RelatorioUsuario.fromMap(Map<String, dynamic> m) => RelatorioUsuario(
    idmatricula: _asInt(m['idmatricula']),
    nomeTitular: m['nome_titular']?.toString(),
  );
}

/// --------------------------- Totais / Pagos -------------------------------

class RelatorioTotais {
  final double A_saldoMesesAnteriores;
  final double B_totalCoparticipacao;
  final double C_debitosAvulsos;
  final double D_descontadoCopart;
  final double E_creditosAvulsos;
  final double ABC_debitosTotal;
  final double DE_creditosTotal;
  final double saldoATransportar;
  final double totalEnviadoDesconto;

  RelatorioTotais({
    required this.A_saldoMesesAnteriores,
    required this.B_totalCoparticipacao,
    required this.C_debitosAvulsos,
    required this.D_descontadoCopart,
    required this.E_creditosAvulsos,
    required this.ABC_debitosTotal,
    required this.DE_creditosTotal,
    required this.saldoATransportar,
    required this.totalEnviadoDesconto,
  });

  factory RelatorioTotais.fromMap(Map<String, dynamic> m) => RelatorioTotais(
    A_saldoMesesAnteriores:
    _asDouble(m['A_saldo_meses_anteriores']) ?? 0.0,
    B_totalCoparticipacao:
    _asDouble(m['B_total_coparticipacao']) ?? 0.0,
    C_debitosAvulsos: _asDouble(m['C_debitos_avulsos']) ?? 0.0,
    D_descontadoCopart:
    _asDouble(m['D_descontado_copart']) ?? 0.0,
    E_creditosAvulsos: _asDouble(m['E_creditos_avulsos']) ?? 0.0,
    ABC_debitosTotal: _asDouble(m['ABC_debitos_total']) ?? 0.0,
    DE_creditosTotal: _asDouble(m['DE_creditros_total'] ?? m['DE_creditos_total']) ?? 0.0,
    saldoATransportar:
    _asDouble(m['saldo_a_transportar']) ?? 0.0,
    totalEnviadoDesconto:
    _asDouble(m['total_enviado_desconto']) ?? 0.0,
  );
}

class RelatorioTotaisPagos {
  final double? totalPago;
  final double? valorTotal;

  RelatorioTotaisPagos({
    this.totalPago,
    this.valorTotal,
  });

  factory RelatorioTotaisPagos.fromMap(Map<String, dynamic> m) =>
      RelatorioTotaisPagos(
        totalPago: _asDouble(m['totalpago']),
        valorTotal: _asDouble(m['valortotal']),
      );
}

/// --------------------------- Itens (copar/extrato) ------------------------

class RelatorioCoparItem {
  final int? tipoCaixa;
  final double? total;
  final Map<String, dynamic> raw;

  RelatorioCoparItem({
    required this.raw,
    this.tipoCaixa,
    this.total,
  });

  factory RelatorioCoparItem.fromMap(Map<String, dynamic> m) =>
      RelatorioCoparItem(
        raw: m,
        tipoCaixa: _asInt(m['tipo_caixa'] ?? m['tipoCaixa'] ?? m['tipo']),
        total: _asDouble(m['total'] ?? m['valor'] ?? m['vl']),
      );
}

/// Itens de extrato podem variar por ambiente. Expomos campos comuns
/// (descricao/valor/competencia/tipoCaixa) e preservamos o mapa bruto.
class ExtratoItem {
  final String? descricao;
  final double? valor;
  final String? competencia; // "MM/YYYY" ou similar
  final int? tipoCaixa;
  final Map<String, dynamic> raw;

  ExtratoItem({
    required this.raw,
    this.descricao,
    this.valor,
    this.competencia,
    this.tipoCaixa,
  });

  factory ExtratoItem.fromMap(Map<String, dynamic> m) => ExtratoItem(
    raw: m,
    descricao: (m['descricao'] ??
        m['desc'] ??
        m['historico'] ??
        m['evento'])
        ?.toString(),
    valor: _asDouble(m['valor'] ?? m['vl'] ?? m['total']),
    competencia: (m['competencia'] ??
        m['mes_ano'] ??
        m['ref'] ??
        m['periodo'])
        ?.toString(),
    tipoCaixa: _asInt(m['tipo_caixa'] ?? m['tipo']),
  );
}
