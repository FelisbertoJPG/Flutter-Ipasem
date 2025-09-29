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

class ComunicadoResumo {
  final String titulo;
  final String descricao;
  final DateTime data;

  const ComunicadoResumo({
    required this.titulo,
    required this.descricao,
    required this.data,
  });
}
