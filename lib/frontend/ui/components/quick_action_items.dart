// lib/ui/components/quick_action_items.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../root_nav_shell.dart';
import 'quick_actions.dart';
import '../../screens/login_screen.dart';
import '../../screens/profile_screen.dart';
import '../../controller/carteirinha_flow_controller.dart';
import '../../screens/authorizations_picker_sheet.dart'
    show showAuthorizationsPickerSheet;
import '../../screens/historico_autorizacoes_screen.dart';
import '../../screens/relatorio_coparticipacao_screen.dart';
import '../../screens/autorizacao_medica_screen.dart';
import '../../screens/autorizacao_odontologica_screen.dart';
import '../../screens/autorizacao_exames_screen.dart';
import '../../screens/retorno_exames_screen.dart';

/// Presets reutilizáveis de QuickActionItem.
///
/// Ideia: em vez de montar todos os itens na Home ou Serviços manualmente,
/// chamamos aqui algo como:
///
///   final items = QuickActionItems.homeDefault(
///     context: context,
///     idMatricula: s.profile?.id,
///   );
///
/// ou, na tela de serviços:
///
///   final items = [
///     QuickActionItems.autorizacaoMedica(context: context),
///     ...
///   ];
class QuickActionItems {
  const QuickActionItems._(); // só estática

  /// Conjunto padrão de ações rápidas da Home.
  ///
  /// A visibilidade real de cada item ainda é controlada por:
  /// - [QaAudience] (all/loggedIn/visitor)
  /// - [requiresLogin] + `isLoggedIn` dentro do widget `QuickActions`.
  static List<QuickActionItem> homeDefault({
    required BuildContext context,
    required int? idMatricula,
  }) {
    return [
      carteirinha(
        context: context,
        idMatricula: idMatricula,
      ),
      autorizacoes(
        context: context,
      ),
      historicoAutorizacoes(
        context: context,
      ),
      servicos(
        context: context,
      ),
      login(
        context: context,
      ),
      perfil(
        context: context,
      ),
    ];
  }

  // =====================================================================
  // ITENS – HOME / GERAIS
  // =====================================================================

  /// Ação rápida da Carteirinha Digital.
  static QuickActionItem carteirinha({
    required BuildContext context,
    required int? idMatricula,
  }) {
    return QuickActionItem(
      id: 'carteirinha',
      label: 'Carteirinha',
      icon: Icons.badge_outlined,
      audience: QaAudience.loggedIn,
      requiresLogin: true,
      onTap: () async {
        final id = idMatricula;
        if (id == null || id <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível carregar a sua matrícula. '
                    'Faça login novamente.',
              ),
            ),
          );
          return;
        }

        await startCarteirinhaFlow(
          context,
          idMatricula: id,
        );
      },
    );
  }

  /// Ação rápida das Autorizações (sheet com as três opções).
  static QuickActionItem autorizacoes({
    required BuildContext context,
  }) {
    return QuickActionItem(
      id: 'autorizacoes',
      label: 'Autorizações',
      icon: Icons.assignment_turned_in_outlined,
      audience: QaAudience.all,
      requiresLogin: true,
      onTap: () async {
        await showAuthorizationsPickerSheet(context);
      },
    );
  }

  /// Ação rápida para Histórico de Autorizações.
  static QuickActionItem historicoAutorizacoes({
    required BuildContext context,
  }) {
    return QuickActionItem(
      id: 'historico_aut',
      label: 'Histórico de Autorizações',
      icon: FontAwesomeIcons.clockRotateLeft,
      audience: QaAudience.loggedIn,
      requiresLogin: true,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const HistoricoAutorizacoesScreen(),
          ),
        );
      },
    );
  }

  /// Ação rápida para trocar para a aba de Serviços (HomeServicos) na RootNavShell.
  ///
  /// Obs.: não tem fallback para `Navigator.push` para evitar dependência circular
  /// com a própria `HomeServicos`.
  static QuickActionItem servicos({
    required BuildContext context,
  }) {
    return QuickActionItem(
      id: 'assistencia',
      label: 'Serviços',
      icon: Icons.local_hospital_outlined,
      audience: QaAudience.all,
      requiresLogin: false,
      onTap: () {
        _switchTab(context, _QuickActionsTabs.servicos);
      },
    );
  }

  /// Ação rápida para Login (visitante).
  static QuickActionItem login({
    required BuildContext context,
  }) {
    return QuickActionItem(
      id: 'login',
      label: 'Fazer login',
      icon: Icons.login_outlined,
      audience: QaAudience.visitor,
      requiresLogin: false,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      },
    );
  }

  /// Ação rápida para abrir o Perfil (aba Perfil ou tela).
  static QuickActionItem perfil({
    required BuildContext context,
  }) {
    return QuickActionItem(
      id: 'perfil',
      label: 'Meu Perfil',
      icon: Icons.person_outline,
      audience: QaAudience.loggedIn,
      requiresLogin: false,
      onTap: () {
        // Tenta navegar para a aba de Perfil na RootNavShell.
        if (_switchTab(context, _QuickActionsTabs.perfil)) return;

        // Fallback se estivermos fora da shell.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ProfileScreen(),
          ),
        );
      },
    );
  }

  // =====================================================================
  // ITENS – TELA DE SERVIÇOS
  // =====================================================================

  static QuickActionItem autorizacaoMedica({
    required BuildContext context,
  }) {
    return QuickActionItem(
      id: 'aut_med',
      label: 'Autorização Médica',
      icon: FontAwesomeIcons.stethoscope,
      audience: QaAudience.loggedIn,
      requiresLogin: false,
      onTap: () {
        final scope = RootNavShell.maybeOf(context);
        if (scope != null) {
          scope.pushInServicos('autorizacao-medica');
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AutorizacaoMedicaScreen()),
          );
        }
      },
    );
  }

  static QuickActionItem autorizacaoOdontologica({
    required BuildContext context,
  }) {
    return QuickActionItem(
      id: 'aut_odo',
      label: 'Autorização Odontológica',
      icon: FontAwesomeIcons.tooth,
      audience: QaAudience.loggedIn,
      requiresLogin: false,
      onTap: () {
        final scope = RootNavShell.maybeOf(context);
        if (scope != null) {
          scope.pushInServicos('autorizacao-odontologica');
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AutorizacaoOdontologicaScreen(),
            ),
          );
        }
      },
    );
  }

  static QuickActionItem autorizacaoExames({
    required BuildContext context,
  }) {
    return QuickActionItem(
      id: 'aut_exames',
      label: 'Autorização de Exames',
      icon: Icons.monitor_heart,
      audience: QaAudience.loggedIn,
      requiresLogin: false,
      onTap: () {
        final scope = RootNavShell.maybeOf(context);
        if (scope != null) {
          scope.pushInServicos('autorizacao-exames');
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AutorizacaoExamesScreen(),
            ),
          );
        }
      },
    );
  }

  static QuickActionItem retornoExames({
    required BuildContext context,
  }) {
    return QuickActionItem(
      id: 'retorno_exames',
      label: 'Retorno de Exames',
      icon: FontAwesomeIcons.listCheck,
      audience: QaAudience.loggedIn,
      requiresLogin: true,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const RetornoExamesScreen(),
          ),
        );
      },
    );
  }

  static QuickActionItem extratoCoparticipacao({
    required BuildContext context,
    required int? idMatricula,
  }) {
    return QuickActionItem(
      id: 'extrato_copart',
      label: 'Extrato Coparticipação',
      icon: FontAwesomeIcons.fileInvoiceDollar,
      audience: QaAudience.loggedIn,
      requiresLogin: true,
      onTap: () {
        final m = idMatricula;
        if (m == null || m <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível carregar a sua matrícula. '
                    'Faça login novamente.',
              ),
            ),
          );
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RelatorioCoparticipacaoScreen(idMatricula: m),
          ),
        );
      },
    );
  }

  /// Item genérico de “Site” que recebe apenas o [onTap].
  static QuickActionItem site({
    required VoidCallback onTap,
  }) {
    return QuickActionItem(
      id: 'site',
      label: 'Site',
      icon: FontAwesomeIcons.globe,
      audience: QaAudience.all,
      requiresLogin: false,
      onTap: onTap,
    );
  }

  // =====================================================================
  // Helpers internos
  // =====================================================================

  static bool _switchTab(BuildContext context, int index) {
    final scope = RootNavShell.maybeOf(context);
    if (scope != null) {
      scope.setTab(index);
      return true;
    }
    return false;
  }
}

/// Índices das abas usados na RootNavShell.
class _QuickActionsTabs {
  static const int home = 0;
  static const int servicos = 1;
  static const int perfil = 2;
}
