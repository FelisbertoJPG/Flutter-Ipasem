import 'package:flutter/material.dart';
import '../ui/app_shell.dart';

class PrivacidadeScreen extends StatelessWidget {
  const PrivacidadeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Privacidade',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Política de Privacidade', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 12),
          Text(
            'Este aplicativo pode armazenar localmente dados mínimos para melhorar a experiência, '
                'como CPF (para autofill) e estado de sessão (is_logged_in). '
                'Nenhum dado é enviado a servidores do IPASEM sem consentimento explícito.',
          ),
          SizedBox(height: 12),
          Text('• CPF é salvo somente no dispositivo (SharedPreferences).'),
          Text('• Você pode limpar os dados pelo menu “Sair”.'),
        ],
      ),
    );
  }
}
