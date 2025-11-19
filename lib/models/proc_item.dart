class ProcItem {
  final String codigo;
  final String descricao;
  final int quantidade;

  const ProcItem({
    required this.codigo,
    required this.descricao,
    this.quantidade = 1,
  });

  factory ProcItem.fromMap(Map<String, dynamic> m) {
    final cod = (m['codigo'] ??
        m['cod_procedimento'] ??
        m['codproc'] ??
        m['procedimento'] ??
        '')
        .toString();

    final desc = (m['descricao'] ??
        m['desc'] ??
        m['nome'] ??
        m['procedimento_descricao'] ??
        '')
        .toString();

    final qtd = int.tryParse(
      (m['quantidade'] ?? m['qtd'] ?? m['qtde'] ?? '1').toString(),
    ) ??
        1;

    return ProcItem(codigo: cod, descricao: desc, quantidade: qtd);
  }
}
