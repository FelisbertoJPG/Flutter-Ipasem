import 'package:flutter/material.dart';

import 'section_card.dart';
import 'loading_placeholder.dart';
import 'locked_notice.dart';
import 'resumo_row.dart';

/// Card da seção "Minha Situação".
/// - Se [isLoading] true: mostra skeleton.
/// - Se não logado: mostra LockedNotice.
/// - Se logado: exibe Situação (padrão "Ativo"), Plano e nº de Dependentes.
///
/// Futuras integrações (SP/API):
/// - Preencher [situacao] e [plano] com dados reais do backend.
class MinhaSituacaoCard extends StatelessWidget {
  const MinhaSituacaoCard({
    super.key,
    required this.isLoading,
    required this.isLoggedIn,
    this.situacao,
    this.plano,
    required this.dependentes,
  });

  final bool isLoading;
  final bool isLoggedIn;
  final String? situacao;
  final String? plano;
  final int dependentes;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Minha Situação',
      child: isLoading
          ? const LoadingPlaceholder(height: 72)
          : (isLoggedIn
          ? _Resumo(
        situacao: situacao ?? 'Ativo', // padrão quando logado
        plano: plano ?? '—',
        dependentes: dependentes,
      )
          : const LockedNotice(
        message:
        'Faça login para visualizar seus dados de situação, plano e dependentes.',
      )),
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({
    required this.situacao,
    required this.plano,
    required this.dependentes,
  });

  final String situacao;
  final String plano;
  final int dependentes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Vínculo -> Situação (conforme solicitado)
        ResumoRow(icon: Icons.verified_user_outlined, label: 'Situação', value: situacao),
        ResumoRow(
          icon: Icons.medical_services_outlined,
          label: 'Plano de saúde',
          value: plano,
        ),
        ResumoRow(
          icon: Icons.group_outlined,
          label: 'Dependentes',
          value: '$dependentes',
        ),
      ],
    );
  }
}
