// lib/screens/sobre_screen.dart
import 'package:flutter/material.dart';
import '../ui/components/info_page.dart';

const _sobreText = '''
IPASEM NH — Aplicativo Oficial

Este aplicativo facilita o acesso a serviços do IPASEM de Novo Hamburgo, como
autorizações, carteirinha digital e comunicados. O objetivo é dar praticidade
e transparência ao beneficiário.

Suporte:
• E-mail: contato@ipasemnh.com.br
• Telefone: (51) 3594-9162
• Site: https://www.ipasemnh.com.br
''';

class SobreScreen extends StatelessWidget {
  const SobreScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const InfoPage(title: 'Sobre', body: _sobreText);
}
