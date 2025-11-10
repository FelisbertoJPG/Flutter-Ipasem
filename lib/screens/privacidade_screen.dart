
// lib/screens/privacidade_screen.dart
import 'package:flutter/material.dart';
import '../ui/components/info_page.dart';

const _privacidadeText = '''
Controlador: IPASEMNH — Instituto de Previdência e Assistência dos Servidores
de Novo Hamburgo.

Dados coletados: identificação (p.ex. CPF), dados de contato, dados de uso do
aplicativo e informações necessárias à execução dos serviços.

Bases legais (LGPD) — conforme o caso:
• Execução de políticas públicas: art. 7º, III, observado o art. 23 (finalidade pública, interesse público e transparência).
• Cumprimento de obrigação legal ou regulatória: art. 7º, II.
• Consentimento do titular: art. 7º, I — apenas para funcionalidades opcionais e não essenciais (ex.: analytics não essencial, notificações não obrigatórias), com possibilidade de revogação.
• Dados pessoais sensíveis, quando estritamente necessários: art. 11, II (ex.: políticas públicas; obrigação legal; tutela da saúde), com salvaguardas adicionais.

Finalidades
• Autenticação e atendimento;
• Emissão de carteirinha digital e gestão de solicitações/autorizações;
• Comunicações institucionais;
• Segurança do ambiente (logs e prevenção a fraudes) e melhoria contínua do serviço com métricas agregadas.

Compartilhamento: apenas com operadores/terceiros estritamente necessários à
prestação dos serviços, observando a LGPD e contratos de processamento.

Retenção: pelo tempo necessário ao atendimento das finalidades e obrigações
legais/regulatórias aplicáveis.

Segurança: adotamos medidas técnicas e administrativas para proteger seus dados.
Nenhuma medida é 100% infalível, mas buscamos padrões atualizados de segurança.

Direitos do titular: confirmação de tratamento, acesso, correção, anonimização,
eliminação, portabilidade, informação sobre compartilhamentos, e revogação do
consentimento (quando aplicável).

Exercício de direitos e contato do DPO: cpd@ipasemnh.com.br

Cookies e analytics: se utilizados, servem para métricas e melhoria do serviço.
Você pode gerenciar permissões nas configurações do dispositivo.

Atualizações: esta política pode ser atualizada.
''';

class PrivacidadeScreen extends StatelessWidget {
  const PrivacidadeScreen({super.key, this.minimal = false});
  final bool minimal;

  @override
  Widget build(BuildContext context) =>
      InfoPage(title: 'Privacidade', body: _privacidadeText, minimal: minimal);
}
