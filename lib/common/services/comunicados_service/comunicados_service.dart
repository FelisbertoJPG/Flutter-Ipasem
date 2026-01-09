// lib/common/services/comunicados_service.dart
import 'dart:async';
import 'dart:collection';

import '../../../backend/models/models.dart' show ComunicadoResumo;
import '../../repositories/comunicados_repository.dart';


/// Serviço de alto nível para listar comunicados com cache em memória.
class ComunicadosService {
  final ComunicadosRepository _repo;
  final Duration cacheTtl;

  final Map<String, _CacheEntry<List<ComunicadoResumo>>> _cacheResumos =
  HashMap();

  ComunicadosService({
    required ComunicadosRepository repository,
    this.cacheTtl = const Duration(minutes: 5),
  }) : _repo = repository;

  static String _key({
    required int limit,
    String? categoria,
    String? q,
  }) {
    return 'limit=$limit'
        '|cat=${(categoria ?? '').trim().toLowerCase()}'
        '|q=${(q ?? '').trim().toLowerCase()}';
  }

  Future<List<ComunicadoResumo>> listar({
    int limit = 10,
    String? categoria,
    String? q,
    bool forceRefresh = false,
  }) async {
    final key = _key(limit: limit, categoria: categoria, q: q);
    final now = DateTime.now();

    if (!forceRefresh && _cacheResumos.containsKey(key)) {
      final c = _cacheResumos[key]!;
      if (now.difference(c.when) <= cacheTtl) {
        return c.value;
      }
    }

    final data = await _repo.listPublicados(
      limit: limit,
      categoria: categoria,
      q: q,
    );

    _cacheResumos[key] = _CacheEntry(value: data, when: now);
    return data;
  }

  void clearCache() => _cacheResumos.clear();
}

class _CacheEntry<T> {
  final T value;
  final DateTime when;

  _CacheEntry({
    required this.value,
    required this.when,
  });
}
