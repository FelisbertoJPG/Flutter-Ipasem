class Especialidade {
  final int id;
  final String nome;
  const Especialidade({required this.id, required this.nome});

  factory Especialidade.fromMap(Map<String,dynamic> m) =>
      Especialidade(id: (m['id'] ?? 0) as int, nome: (m['nome'] ?? '') as String);
}
