// lib/screens/termos_screen.dart
import 'package:flutter/material.dart';
import '../ui/components/info_page.dart';

const _termosText = '''
Termos de Uso:
1. Aceite — Ao utilizar o app, você concorda com estes Termos.
2. Público-alvo — Servidores/beneficiários com cadastro ativo no IPASEM.
3. Serviços — Consulta de informações, autorizações, carteirinha e comunicados.
4. Cadastro e acesso — O acesso pode exigir CPF e senha; mantenha suas credenciais
em sigilo. Você é responsável pelas ações realizadas na sua conta.
5. Uso adequado — É vedado uso fraudulento, engenharia reversa, ataques ou qualquer
atividade contrária à lei ou que comprometa o serviço.
6. Conteúdos de terceiros — Links externos podem existir; o IPASEM não se
responsabiliza por serviços de terceiros.
7. Disponibilidade — O app pode passar por manutenção ou indisponibilidade
eventual. Empregamos esforços para estabilidade e correções.
8. Responsabilidade — O IPASEM não responde por danos indiretos/incidentais
decorrentes do uso, na máxima extensão permitida em lei.
9. Alterações — Os Termos podem ser atualizados a qualquer tempo. O uso após
alterações implica concordância.
10. Lei e foro — Legislação brasileira. Foro: Novo Hamburgo/RS.
11. Suporte — suporte@ipasemnh.com.br
Vigência: 26/09/2025
''';

class TermosScreen extends StatelessWidget {
  const TermosScreen({super.key, this.minimal = false});
  final bool minimal;

  @override
  Widget build(BuildContext context) =>
      InfoPage(title: 'Termos de Uso', body: _termosText, minimal: minimal);
}

