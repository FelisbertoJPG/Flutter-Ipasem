// lib/features/comunicados/comunicados_repository.dart

import 'dart:async';
import '../api/api_myadmin.dart' show ApiMyAdmin, Comunicado;
import '../core/models.dart' show ComunicadoResumo;

class ComunicadosRepository {
  // Cliente interno (injeta default se não for passado)
  final ApiMyAdmin _api;

  // >>> MODO COMPATÍVEL: permite chamar ComunicadosRepository() sem args
  // Ajuste o BASE/PATH conforme seu ambiente.
  static const String _kDefaultBase = 'http://192.9.200.98:81';
  static const String _kDefaultPath = '/api-dev.php';

  ComunicadosRepository([ApiMyAdmin? api])
      : _api = api ?? ApiMyAdmin(_kDefaultBase, apiPath: _kDefaultPath);

  /// NOVO: lista publicados com filtros opcionais
  Future<List<ComunicadoResumo>> listPublicados({
    int limit = 10,
    String? categoria,
    String? q,
  }) async {
    final list = await _api.listarComunicados(
      limit: limit,
      categoria: categoria,
      q: q,
    );

    // Mantém o mapping centralizado neste repositório para não quebrar o core/models.dart
    return list.map(_mapToResumo).toList();
  }

  /// COMPAT: alias para não quebrar chamadas antigas
  Future<List<ComunicadoResumo>> fetchResumos({int limit = 10}) {
    return listPublicados(limit: limit);
  }

  Future<Comunicado> getDetalhe(int id) => _api.obterComunicado(id);

  // ---- helpers ----
  static ComunicadoResumo _mapToResumo(Comunicado c) {
    // Preferir resumo curto; se vier nulo, usar primeiras linhas do corpo.
    final desc = (c.resumo != null && c.resumo!.trim().isNotEmpty)
        ? c.resumo!.trim()
        : _firstLines(c.corpo, 160);

    return ComunicadoResumo(
      id: c.id,
      titulo: c.titulo,
      descricao: desc,
      data: c.publicadoEm, // pode ser null; UI lida com fallback
    );
  }

  static String _firstLines(String s, int max) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= max) return t;
    return t.substring(0, max).trimRight() + '…';
  }
}
