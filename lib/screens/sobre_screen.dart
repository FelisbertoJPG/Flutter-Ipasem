import 'package:flutter/material.dart';
import '../ui/app_shell.dart';

class SobreScreen extends StatelessWidget {
  const SobreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Sobre',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('IPASEM App', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text('Versão 0.1.0'),
          SizedBox(height: 16),
          Text(
            'Aplicativo oficial do IPASEM. Este app oferece acesso a carteirinha digital, '
                'autorizações e informações do usuário. Em desenvolvimento.',
          ),
        ],
      ),
    );
  }
}
