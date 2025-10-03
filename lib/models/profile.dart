// lib/models/profile.dart
class Profile {
  final int id;
  final String nome;
  final String cpf;
  final String? email;
  final String? email2;

  Profile({required this.id, required this.nome, required this.cpf, this.email, this.email2});

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
    id: (m['id'] as num).toInt(),
    nome: m['nome'] as String,
    cpf: m['cpf'] as String,
    email: m['email'] as String?,
    email2: m['email2'] as String?,
  );
}
