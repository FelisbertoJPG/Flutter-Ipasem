import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/digital_card.dart';

class CarteirinhaPage extends StatefulWidget {
  const CarteirinhaPage({super.key});

  @override
  State<CarteirinhaPage> createState() => _CarteirinhaPageState();
}

class _CarteirinhaPageState extends State<CarteirinhaPage> {
  late final ApiService api;
  Future<(UserProfile,List<Dep>)>? future;

  @override
  void initState() {
    super.initState();
    api = ApiService('https://assistweb.ipasemnh.com.br'); // BASE
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final tk = prefs.getString('token_login');
    if (tk == null || tk.isEmpty) {
      setState(()=>future = Future.error('Sem token. Faça login pelo app.'));
      return;
    }
    setState(()=>future = api.fetchCarteirinha(tokenLogin: tk));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minha carteirinha')),
      body: FutureBuilder<(UserProfile,List<Dep>)>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }
          final (user, deps) = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DigitalCard(
                nome: user.nome,
                cpf: user.cpf,
                matricula: user.matricula,
                plano: user.plano,
                validade: user.validade,
              ),
              const SizedBox(height: 16),
              if (deps.isNotEmpty) ...[
                const Text('Dependentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final d in deps) Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DigitalCard(
                    nome: d.nome,
                    cpf: d.cpf,
                    matricula: user.matricula,
                    plano: user.plano,
                    validade: user.validade,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
