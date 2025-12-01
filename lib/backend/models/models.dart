import '../../common/api/api_myadmin.dart';

class RequerimentoResumo {
  final String titulo;
  final String status;
  final DateTime atualizadoEm;

  const RequerimentoResumo({
    required this.titulo,
    required this.status,
    required this.atualizadoEm,
  });
}

/// View-model leve para listar comunicados no painel.
/// É derivado de `Comunicado` (DTO do backend).
class ComunicadoResumo {
  final int id;
  final String titulo;
  final String? descricao; // usa resumo; senão, corpo truncado
  final DateTime? data;    // publicadoEm

  ComunicadoResumo({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.data,
  });

  /// Trunca preservando palavras.
  static String _ellipsis(String s, {int max = 160}) {
    if (s.length <= max) return s;
    final cut = s.substring(0, max);
    final lastSpace = cut.lastIndexOf(' ');
    final base = lastSpace > 0 ? cut.substring(0, lastSpace) : cut;
    return '$base…';
  }

  /// Mapper a partir do DTO completo.
  factory ComunicadoResumo.fromComunicado(Comunicado c, {int maxLen = 160}) {
    final desc = c.resumo?.trim().isNotEmpty == true
        ? c.resumo!.trim()
        : _ellipsis(c.corpo.trim(), max: maxLen);
    return ComunicadoResumo(
      id: c.id,
      titulo: c.titulo,
      descricao: desc.isEmpty ? null : desc,
      data: c.publicadoEm,
    );
  }
}

