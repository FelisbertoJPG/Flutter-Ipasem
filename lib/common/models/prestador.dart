// lib/models/prestador.dart
class PrestadorRow {
  final String registro;
  final String tipoPrestador; // 'PF'/'PJ' etc
  final String nome;

  // extras p/ card
  final String? vinculo;      // código
  final String? vinculoNome;  // ex.: "CREDENCIAMENTO DIRETO IPASEM"
  final String? endereco;
  final String? bairro;
  final String? cidade;
  final String? uf;

  const PrestadorRow({
    required this.registro,
    required this.tipoPrestador,
    required this.nome,
    this.vinculo,
    this.vinculoNome,
    this.endereco,
    this.bairro,
    this.cidade,
    this.uf,
  });

  /// Novo factory usado pela API atual
  factory PrestadorRow.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => (v ?? '').toString();
    return PrestadorRow(
      registro:      s(j['registro']),
      tipoPrestador: s(j['tipo_prestador']),
      nome:          s(j['nome']),
      vinculo:       j['vinculo'] == null ? null : s(j['vinculo']),
      vinculoNome:   j['vinculo_nome'] == null ? null : s(j['vinculo_nome']),
      endereco:      j['endereco'] == null ? null : s(j['endereco']),
      bairro:        j['bairro'] == null ? null : s(j['bairro']),
      cidade:        j['cidade'] == null ? null : s(j['cidade']),
      uf:            j['uf'] == null ? null : s(j['uf']),
    );
  }

  /// Alias para não quebrar quem ainda chama `fromMap`
  factory PrestadorRow.fromMap(Map<String, dynamic> m) => PrestadorRow.fromJson(m);
}
