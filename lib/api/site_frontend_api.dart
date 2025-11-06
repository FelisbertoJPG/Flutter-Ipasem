import 'dart:convert';
import 'package:http/http.dart' as http;

class SiteFrontendApi {
  final String baseUrl; // ex.: https://www.ipasemnh.com.br

  const SiteFrontendApi(this.baseUrl);

  Uri _u(String path, [Map<String, dynamic>? q]) {
    return Uri.parse(baseUrl + path).replace(
      queryParameters: q?.map((k, v) => MapEntry(k, '$v')),
    );
  }

  /// Chama /comunicacao-app/cards?format=json
  Future<Map<String, dynamic>> fetchComunicadosJson({
    int limit = 6,
    int offset = 0,
  }) async {
    final uri = _u('/comunicacao-app/cards', {
      'format': 'json',
      'limit': limit,
      'offset': offset,
    });

    final resp = await http.get(uri, headers: {
      'Accept': 'application/json',
    });

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode} ao buscar comunicados');
    }

    final map = json.decode(resp.body) as Map<String, dynamic>;
    if (map['ok'] != true) {
      throw Exception('Resposta não-ok do servidor');
    }
    return map;
  }

  /// Opcional: detalhe por ID via controller já existente (api-view).
  /// Mantém r=comunicacao-app/api-view por compatibilidade.
  Future<Map<String, dynamic>> fetchComunicadoById(int id) async {
    final uri = Uri.parse(
      '$baseUrl/index.php?r=comunicacao-app/api-view&id=$id',
    );
    final resp = await http.get(uri, headers: {'Accept': 'application/json'});
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode} ao buscar comunicado $id');
    }
    final map = json.decode(resp.body) as Map<String, dynamic>;
    if (map['ok'] != true) {
      throw Exception('Resposta não-ok ao buscar comunicado $id');
    }
    return map;
  }
}
