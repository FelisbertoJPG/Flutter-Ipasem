import 'dart:convert';

import 'relatorio_coparticipacao.dart' show RelatorioUsuario, RelatorioError;

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  if (v is bool) return v ? 1 : 0;
  return null;
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    final direct = double.tryParse(s);
    if (direct != null) return direct;
    final normalized = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }
  if (v is bool) return v ? 1.0 : 0.0;
  return null;
}

bool _asBoolIrpf(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    return s == '1' || s == 'true' || s == 'yes' || s == 'y' || s == 'on';
  }
  return false;
}

/// --------------------------- Top-level response ---------------------------

class RelatorioIrpfResponse {
  final bool ok;
  final RelatorioIrpfData? data;
  final Map<String, dynamic>? meta;
  final RelatorioError? error;

  RelatorioIrpfResponse({
    required this.ok,
    this.data,
    this.meta,
    this.error,
  });

  factory RelatorioIrpfResponse.fromMap(Map<String, dynamic> m) =>
      RelatorioIrpfResponse(
        ok: _asBoolIrpf(m['ok']),
        data: m['data'] is Map<String, dynamic>
            ? RelatorioIrpfData.fromMap(m['data'] as Map<String, dynamic>)
            : null,
        meta: m['meta'] is Map<String, dynamic>
            ? (m['meta'] as Map<String, dynamic>)
            : null,
        error: m['error'] is Map<String, dynamic>
            ? RelatorioError.fromMap(m['error'] as Map<String, dynamic>)
            : null,
      );

  static RelatorioIrpfResponse fromJson(String s) =>
      RelatorioIrpfResponse.fromMap(json.decode(s) as Map<String, dynamic>);
}

/// --------------------------- Payload principal ----------------------------

class RelatorioIrpfData {
  final RelatorioIrpfPeriodo periodo;
  final RelatorioUsuario? usuario;
  final List<IrpfItem> pago;
  final List<IrpfItem> dedutivel;
  final RelatorioIrpfTotais totais;

  RelatorioIrpfData({
    required this.periodo,
    required this.usuario,
    required this.pago,
    required this.dedutivel,
    required this.totais,
  });

  factory RelatorioIrpfData.fromMap(Map<String, dynamic> m) {
    final demo = m['demonstrativo'] as Map<String, dynamic>? ?? const {};
    final pagoRaw = (demo['pago'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final dedRaw = (demo['dedutivel'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return RelatorioIrpfData(
      periodo: RelatorioIrpfPeriodo.fromMap(
        (m['periodo'] ?? const {}) as Map<String, dynamic>,
      ),
      usuario: m['usuario'] is Map<String, dynamic>
          ? RelatorioUsuario.fromMap(m['usuario'] as Map<String, dynamic>)
          : null,
      pago: pagoRaw.map(IrpfItem.fromMap).toList(),
      dedutivel: dedRaw.map(IrpfItem.fromMap).toList(),
      totais: RelatorioIrpfTotais.fromMap(
        (m['totais'] ?? const {}) as Map<String, dynamic>,
      ),
    );
  }
}

class RelatorioIrpfPeriodo {
  final int? anoInicio;

  RelatorioIrpfPeriodo({this.anoInicio});

  factory RelatorioIrpfPeriodo.fromMap(Map<String, dynamic> m) =>
      RelatorioIrpfPeriodo(
        anoInicio: _asInt(m['ano_inicio']),
      );
}

class RelatorioIrpfTotais {
  final double totalPago;
  final double totalDedutivel;

  RelatorioIrpfTotais({
    required this.totalPago,
    required this.totalDedutivel,
  });

  factory RelatorioIrpfTotais.fromMap(Map<String, dynamic> m) =>
      RelatorioIrpfTotais(
        totalPago: _asDouble(m['totalPago']) ?? 0.0,
        totalDedutivel: _asDouble(m['totalDedutivel']) ?? 0.0,
      );
}

class IrpfItem {
  final int? idmatricula;
  final int? iddependente;
  final int? exercicio;
  final String? nomeTitular;
  final String? nomeDependente;
  final int? tipoLancamento;
  final double? valor;
  final Map<String, dynamic> raw;

  IrpfItem({
    required this.raw,
    this.idmatricula,
    this.iddependente,
    this.exercicio,
    this.nomeTitular,
    this.nomeDependente,
    this.tipoLancamento,
    this.valor,
  });

  factory IrpfItem.fromMap(Map<String, dynamic> m) => IrpfItem(
    raw: m,
    idmatricula: _asInt(m['idmatricula']),
    iddependente: _asInt(m['iddependente']),
    exercicio: _asInt(m['exercicio']),
    nomeTitular: m['nome_titular']?.toString(),
    nomeDependente: m['nome_dependente']?.toString(),
    tipoLancamento: _asInt(m['tipo_lancamento']),
    valor: _asDouble(m['valor']),
  );
}
