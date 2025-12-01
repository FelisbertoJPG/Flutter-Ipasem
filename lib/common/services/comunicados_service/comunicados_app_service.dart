import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/comunicado.dart';

/// Ajuste esta BASE para o seu domínio.
/// Ex.: https://www.ipasemnh.com.br
const String kBaseUrl = 'https://SEU-DOMINIO-AQUI';

/// Caminho raiz do controller que renderiza as "views JSON".
/// Mantém coerência com o Yii: /comunicacao-app/api-*
const String kComunicacaoPath = '/comunicacao-app';

class ComunicacaoAppService {
  final Dio _dio;

  ComunicacaoAppService({Dio? dio})
      : _dio = dio ??
      Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        // Aceita JSON; o backend já envia CORS e content-type correto
        headers: {
          'Accept': 'application/json',
        },
        validateStatus: (s) => s != null && s >= 200 && s < 500,
      ));

  Uri _u(String path, [Map<String, dynamic>? q]) {
    return Uri.parse(kBaseUrl).replace(
      path: '${Uri.parse(kBaseUrl).path}$path',
      queryParameters: q,
    );
  }

  bool _isLikelyJson(Response r) {
    final ct = (r.headers['content-type'] ?? r.headers['Content-Type'])?.join(',') ?? '';
    if (ct.toLowerCase().contains('application/json')) return true;
    // fallback: tenta decodificar
    if (r.data is Map || r.data is List) return true;
    if (r.data is String) {
      final s = r.data as String;
      return s.trim().startsWith('{') || s.trim().startsWith('[');
    }
    return false;
  }

  Map<String, dynamic>? _forceMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final dec = json.decode(data);
        if (dec is Map<String, dynamic>) return dec;
      } catch (_) {}
    }
    return null;
  }

  /// GET /comunicacao-app/api-ping
  Future<bool> ping() async {
    final url = _u('$kComunicacaoPath/api-ping');
    final r = await _dio.getUri(url);
    if (!_isLikelyJson(r)) return false;

    final m = _forceMap(r.data);
    if (m == null) return false;
    final ok = m['ok'] == true;
    final data = m['data'];
    if (ok && data is Map && data['service'] == 'comunicacao-app') return true;
    return ok;
  }

  /// GET/POST /comunicacao-app/api-list
  /// Filtros: limit, offset, categoria, tag
  Future<PaginatedComunicados> list({
    int limit = 20,
    int offset = 0,
    String? categoria,
    String? tag,
  }) async {
    final url = _u('$kComunicacaoPath/api-list');
    final payload = {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (categoria != null && categoria.isNotEmpty) 'categoria': categoria,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
    };

    final r = await _dio.postUri(url, data: payload);

    if (!_isLikelyJson(r)) {
      // backend respondeu HTML ou outra coisa; trate como vazio
      return PaginatedComunicados(rows: const [], limit: limit, offset: offset);
    }

    final root = _forceMap(r.data) ?? {};
    if (root['ok'] != true) {
      return PaginatedComunicados(rows: const [], limit: limit, offset: offset);
    }

    final data = root['data'];
    if (data is Map) {
      final rows = (data['rows'] is List) ? (data['rows'] as List) : const [];
      final parsed = rows
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>())
          .map(Comunicado.fromApi)
          .toList();
      final lim = int.tryParse('${data['limit'] ?? limit}') ?? limit;
      final off = int.tryParse('${data['offset'] ?? offset}') ?? offset;
      return PaginatedComunicados(rows: parsed, limit: lim, offset: off);
    }

    return PaginatedComunicados(rows: const [], limit: limit, offset: offset);
  }

  /// GET /comunicacao-app/api-view?id=123
  Future<Comunicado?> view(int id, {bool includeExpired = false}) async {
    if (id <= 0) return null;
    final url = _u('$kComunicacaoPath/api-view', {
      'id': '$id',
      if (includeExpired) 'includeExpired': '1',
    });

    final r = await _dio.getUri(url);
    if (!_isLikelyJson(r)) return null;

    final root = _forceMap(r.data) ?? {};
    if (root['ok'] != true) return null;

    final data = root['data'];
    if (data is Map) {
      return Comunicado.fromApi(data.cast<String, dynamic>());
    }
    return null;
  }
}
