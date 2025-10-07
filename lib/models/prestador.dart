class PrestadorRow {
  final String registro;
  final String tipoPrestador; // 'PF'/'PJ'...
  final String nome;
  final String? vinculo;
  final String? endereco;
  final String? bairro;
  final String? cidade;
  final String? uf;

  const PrestadorRow({
    required this.registro,
    required this.tipoPrestador,
    required this.nome,
    this.vinculo,
    this.endereco,
    this.bairro,
    this.cidade,
    this.uf,
  });

  factory PrestadorRow.fromMap(Map<String,dynamic> m) => PrestadorRow(
    registro: (m['registro'] ?? '').toString(),
    tipoPrestador: (m['tipo_prestador'] ?? '').toString(),
    nome: (m['nome'] ?? '').toString(),
    vinculo: m['vinculo'] as String?,
    endereco: m['endereco'] as String?,
    bairro: m['bairro'] as String?,
    cidade: m['cidade'] as String?,
    uf: m['uf'] as String?,
  );
}
