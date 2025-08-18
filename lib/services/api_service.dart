import 'dart:convert';
import 'package:http/http.dart' as http;

class UserProfile {
  final String nome, cpf, matricula, plano, validade;
  UserProfile({required this.nome, required this.cpf, required this.matricula, required this.plano, required this.validade});
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    nome: j['titular']['nome'] ?? '',
    cpf: j['titular']['cpf'] ?? '',
    matricula: j['titular']['matricula'] ?? '',
    plano: j['titular']['plano'] ?? '',
    validade: j['titular']['validade'] ?? '',
  );
}

class Dep {
  final String nome, cpf;
  final int? idade;
  Dep({required this.nome, required this.cpf, this.idade});
  factory Dep.fromJson(Map<String,dynamic> j) => Dep(
    nome: j['nome_paciente'] ?? '',
    cpf: j['cpf'] ?? '',
    idade: j['idade'] is int ? j['idade'] : int.tryParse('${j['idade'] ?? ''}'),
  );
}

class ApiService {
  final String baseUrl; // ex: https://assistweb.ipasemnh.com.br
  ApiService(this.baseUrl);

  Future<(UserProfile,List<Dep>)> fetchCarteirinha({required String tokenLogin}) async {
    final uri = Uri.parse('$baseUrl/mobile/carteirinha?token_login=$tokenLogin');
    final res = await http.get(uri, headers: {'Accept':'application/json'});
    if (res.statusCode != 200) {
      throw Exception('Erro ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String,dynamic>;
    final user = UserProfile.fromJson(data);
    final deps = (data['dependentes'] as List? ?? []).map((e)=>Dep.fromJson(e as Map<String,dynamic>)).toList();
    return (user, deps);
  }
}
