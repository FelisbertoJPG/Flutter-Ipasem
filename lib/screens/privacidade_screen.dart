
// lib/screens/privacidade_screen.dart
import 'package:flutter/material.dart';
import '../ui/components/info_page.dart';

const _privacidadeText = '''
Controlador: IPASEM — Instituto de Previdência e Assistência dos Servidores
de Novo Hamburgo.
Encarregado (DPO): dpo@ipasemnh.com.br

Dados coletados: identificação (p.ex. CPF), dados de contato, dados de uso do
aplicativo e informações necessárias à execução dos serviços.

Bases legais (LGPD): execução de políticas públicas (art. 7º, III e art. 23),
cumprimento de obrigação legal/regulatória, e, quando necessário, consentimento.

Finalidades: autenticação, emissão de carteirinha, solicitações/autorizações,
comunicações institucionais, suporte e melhoria do serviço.

Compartilhamento: apenas com operadores/terceiros estritamente necessários à
prestação dos serviços, observando a LGPD e contratos de processamento.

Retenção: pelo tempo necessário ao atendimento das finalidades e obrigações
legais/regulatórias aplicáveis.

Segurança: adotamos medidas técnicas e administrativas para proteger seus dados.
Nenhuma medida é 100% infalível, mas buscamos padrões atualizados de segurança.

Direitos do titular: confirmação de tratamento, acesso, correção, anonimização,
eliminação, portabilidade, informação sobre compartilhamentos, e revogação do
consentimento (quando aplicável).

Exercício de direitos e contato do DPO: dpo@ipasemnh.com.br

Cookies e analytics: se utilizados, servem para métricas e melhoria do serviço.
Você pode gerenciar permissões nas configurações do dispositivo.

Atualizações: esta política pode ser atualizada. Vigência: 26/09/2025.
''';

class PrivacidadeScreen extends StatelessWidget {
  const PrivacidadeScreen({super.key, this.minimal = false});
  final bool minimal;

  @override
  Widget build(BuildContext context) =>
      InfoPage(title: 'Privacidade', body: _privacidadeText, minimal: minimal);
}
