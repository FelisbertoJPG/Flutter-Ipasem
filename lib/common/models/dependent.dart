// lib/common/models/dependent.dart
class Dependent {
  final String nome;
  final int idmatricula;
  final int iddependente;
  final String? sexo;
  final int? idade;
  final String? cpf;
  final String? dtNasc; // manter string; formata na UI

  Dependent({
    required this.nome,
    required this.idmatricula,
    required this.iddependente,
    this.sexo,
    this.idade,
    this.cpf,
    this.dtNasc,
  });

  factory Dependent.fromMap(Map m) => Dependent(
    nome: (m['nome'] ?? '') as String,
    idmatricula: (m['idmatricula'] ?? 0) as int,
    iddependente: (m['iddependente'] ?? 0) as int,
    sexo: m['sexo'] as String?,
    idade: (m['idade'] is int) ? m['idade'] as int : int.tryParse('${m['idade']}'),
    cpf: m['cpf'] as String?,
    dtNasc: m['dt_nasc'] as String?,
  );
}
