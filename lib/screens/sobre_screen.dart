// lib/screens/sobre_screen.dart
import 'package:flutter/material.dart';
import '../ui/components/info_page.dart';

const _sobreText = '''
IPASEM NH — Aplicativo Oficial
Versão: 1.0.0  •  Última atualização: 2025-09-26

Este aplicativo facilita o acesso a serviços do IPASEM de Novo Hamburgo, como
autorizações, carteirinha digital e comunicados. O objetivo é dar praticidade
e transparência ao beneficiário.

Suporte:
• E-mail: suporte@ipasemnh.com.br
• Telefone/WhatsApp: (51) 0000-0000
• Site: https://www.ipasemnh.com.br
''';

class SobreScreen extends StatelessWidget {
  const SobreScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const InfoPage(title: 'Sobre', body: _sobreText);
}
