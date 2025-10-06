import 'dart:async';
import '../core/models.dart'; // ComunicadoResumo

/// Repositório de Comunicados.
/// Integre a chamada de API aqui (ver TODO).
class ComunicadosRepository {
  const ComunicadosRepository();

  /// Lista comunicados publicados (ordem decrescente por data).
  Future<List<ComunicadoResumo>> listPublicados({int limit = 10}) async {
    // TODO: aqui vai ser posto via API
    // Exemplo (ilustrativo):
    // final resp = await _api.get('/comunicados', query: {'limit': '$limit'});
    // final data = resp.data as List;
    // return data.map((j) => ComunicadoResumo.fromJson(j)).toList();

    return const <ComunicadoResumo>[]; // vazio por enquanto
  }
}
