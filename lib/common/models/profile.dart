// lib/models/profile.dart

class Profile {
  final int id;
  final String nome;
  final String cpf;
  final String? email;
  final String? email2;

  /// Sexo "bruto" que venha do backend: "M", "F", etc. (opcional)
  final String? sexo;

  /// Texto de sexo, caso o backend envie algo como "Masculino" / "Feminino".
  final String? sexoTxt;

  Profile({
    required this.id,
    required this.nome,
    required this.cpf,
    this.email,
    this.email2,
    this.sexo,
    this.sexoTxt,
  });

  /// Cria o Profile a partir de um mapa retornado pelo backend.
  ///
  /// - `sexo` tenta ler de `sexo` ou `genero`;
  /// - `sexoTxt` tenta ler de `sexo_txt`, `sexoTxt` ou `sexo_texto`;
  /// Todos são opcionais. Se o backend não mandar nada, ficam `null`.
  factory Profile.fromMap(Map<String, dynamic> m) {
    final rawSexo     = m['sexo'] ?? m['genero'];
    final rawSexoTxt  = m['sexo_txt'] ?? m['sexoTxt'] ?? m['sexo_texto'];

    return Profile(
      id: (m['id'] as num).toInt(),
      nome: m['nome'] as String,
      cpf: m['cpf'] as String,
      email: m['email'] as String?,
      email2: m['email2'] as String?,
      sexo: rawSexo?.toString(),
      sexoTxt: rawSexoTxt?.toString(),
    );
  }

  /// Facilita atualizar campos isoladamente (inclusive sexo/sexoTxt) mantendo o resto.
  Profile copyWith({
    int? id,
    String? nome,
    String? cpf,
    String? email,
    String? email2,
    String? sexo,
    String? sexoTxt,
  }) {
    return Profile(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      cpf: cpf ?? this.cpf,
      email: email ?? this.email,
      email2: email2 ?? this.email2,
      sexo: sexo ?? this.sexo,
      sexoTxt: sexoTxt ?? this.sexoTxt,
    );
  }
}
