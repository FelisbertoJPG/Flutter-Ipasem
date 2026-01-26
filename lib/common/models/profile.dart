// lib/common/models/profile.dart

class Profile {
  /// Para titular e dependente, usamos o mesmo campo `id` como
  /// "id da matrícula" (idmatricula).
  final int id;

  /// Quando for dependente, vem preenchido com o ID do dependente (> 0).
  /// Para titular, vem 0 ou null.
  final int? idDependente;

  final String nome;
  final String cpf;
  final String? email;
  final String? email2;

  /// Sexo "bruto" que venha do backend: "M", "F", etc. (opcional)
  final String? sexo;

  /// Texto de sexo, caso o backend envie algo como "Masculino" / "Feminino".
  final String? sexoTxt;

  /// Dados extras pensados para o dependente, mas opcionais.
  final String? grauParentesco;
  final int? idSituacao;
  final int? idTipo;
  final DateTime? dataNascimento;

  const Profile({
    required this.id,
    required this.nome,
    required this.cpf,
    this.idDependente,
    this.email,
    this.email2,
    this.sexo,
    this.sexoTxt,
    this.grauParentesco,
    this.idSituacao,
    this.idTipo,
    this.dataNascimento,
  });

  /// Indica rapidamente se este profile representa um DEPENDENTE.
  ///
  /// Regra: idDependente > 0  ⇒ dependente
  ///        idDependente == 0 ou null ⇒ titular
  bool get isDependente => (idDependente ?? 0) > 0;

  /// Conveniência: contexto de titular.
  bool get isTitular => !isDependente;

  /// Matrícula composta no padrão usado pelo site:
  /// - Titular:  7277
  /// - Depend.:  7277-3
  String get matriculaComposta {
    final dep = idDependente ?? 0;
    if (dep <= 0) return '$id';
    return '$id-$dep';
  }

  /// Cria o Profile a partir de um mapa retornado pelo backend.
  ///
  /// Mantém compatibilidade com o login do titular e já suporta
  /// o retorno planejado para o dependente:
  ///
  /// Titular (exemplo):
  /// {
  ///   "id": 1234,
  ///   "nome": "Fulano",
  ///   "cpf": "00000000000",
  ///   "email": "...",
  ///   "sexo": "M",
  ///   "sexo_txt": "Masculino"
  /// }
  ///
  /// Dependente (exemplo planejado para api-dev.php?action=dependente_login):
  /// {
  ///   "idmatricula": 1234,
  ///   "iddependente": 5,
  ///   "cpf": "00000000000",
  ///   "nome": "Fulano Filho",
  ///   "email": "...",
  ///   "email2": "...",
  ///   "sexo": "M",
  ///   "data_nascimento": "2005-03-10",
  ///   "grau_parentesco": "Filho",
  ///   "idsituacao": 1,
  ///   "idtipo": 2
  /// }
  factory Profile.fromMap(Map<String, dynamic> m) {
    int _toInt(dynamic v) {
      if (v == null) throw ArgumentError('Valor numérico nulo');
      if (v is num) return v.toInt();
      return int.parse(v.toString());
    }

    DateTime? _parseDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;

      // Aceita "dd/MM/yyyy", "dd-MM-yyyy" ou "yyyy-MM-dd".
      var norm = s.replaceAll('/', '-');
      final parts = norm.split('-');
      if (parts.length == 3 && parts[0].length == 2 && parts[2].length == 4) {
        // Parece dd-MM-yyyy
        norm = '${parts[2]}-${parts[1]}-${parts[0]}';
      }

      try {
        return DateTime.parse(norm);
      } catch (_) {
        return null;
      }
    }

    final rawId = m['id'] ?? m['idmatricula'] ?? m['matricula'];
    if (rawId == null) {
      throw ArgumentError(
        'Profile.fromMap: campo "id" ou "idmatricula" é obrigatório',
      );
    }

    final rawDepId =
        m['iddependente'] ?? m['dependente'] ?? m['id_dep'] ?? m['dep'];

    final rawSexo = m['sexo'] ?? m['genero'];
    final rawSexoTxt = m['sexo_txt'] ?? m['sexoTxt'] ?? m['sexo_texto'];

    final nome =
    (m['nome'] ?? m['nome_completo'] ?? '').toString().trim();
    final cpf = (m['cpf'] ?? '').toString().trim();

    // Se vier 0 do backend, tratamos como "sem dependente" (titular)
    final int? depId =
    rawDepId == null ? null : _toInt(rawDepId) == 0 ? null : _toInt(rawDepId);

    return Profile(
      id: _toInt(rawId),
      idDependente: depId,
      nome: nome,
      cpf: cpf,
      email: m['email'] as String?,
      email2: m['email2'] as String?,
      sexo: rawSexo?.toString(),
      sexoTxt: rawSexoTxt?.toString(),
      grauParentesco:
      (m['grau_parentesco'] ?? m['grauParentesco'])?.toString(),
      idSituacao:
      m['idsituacao'] != null ? _toInt(m['idsituacao']) : null,
      idTipo: m['idtipo'] != null ? _toInt(m['idtipo']) : null,
      dataNascimento: _parseDate(
        m['data_nascimento'] ?? m['dataNascimento'] ?? m['dtnasc'],
      ),
    );
  }

  /// Facilita atualizar campos isoladamente mantendo o resto.
  Profile copyWith({
    int? id,
    int? idDependente,
    String? nome,
    String? cpf,
    String? email,
    String? email2,
    String? sexo,
    String? sexoTxt,
    String? grauParentesco,
    int? idSituacao,
    int? idTipo,
    DateTime? dataNascimento,
  }) {
    return Profile(
      id: id ?? this.id,
      idDependente: idDependente ?? this.idDependente,
      nome: nome ?? this.nome,
      cpf: cpf ?? this.cpf,
      email: email ?? this.email,
      email2: email2 ?? this.email2,
      sexo: sexo ?? this.sexo,
      sexoTxt: sexoTxt ?? this.sexoTxt,
      grauParentesco: grauParentesco ?? this.grauParentesco,
      idSituacao: idSituacao ?? this.idSituacao,
      idTipo: idTipo ?? this.idTipo,
      dataNascimento: dataNascimento ?? this.dataNascimento,
    );
  }
}
