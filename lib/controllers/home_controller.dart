// lib/controllers/home_controller.dart
import 'package:flutter/foundation.dart';

import '../data/session_store.dart';
import '../services/session.dart';
import '../repositories/dependents_repository.dart';
import '../services/dependent_utils.dart';     // removeTitularFromList(Profile, List<Dependent>)
import '../core/models.dart';                 // RequerimentoResumo, ComunicadoResumo
import '../models/dependent.dart';            // Tipo Dependent

// IMPORTANTE: use SEMPRE este shim para referenciar o HomeState/Controller.
// Não importe também 'home_state.dart' direto em outros arquivos.
import 'home_state_controller.dart';          // reexporta HomeState

/// Controlador da Home.
/// - Carrega status de login, CPF salvo e perfil atual.
/// - Busca dependentes via repo e remove o titular da contagem/exibição.
/// - Expõe um `HomeState` que a tela observa (AnimatedBuilder/ChangeNotifier).
class HomeController extends ChangeNotifier {
  final SessionStore session;
  final DependentsRepository depsRepo;

  HomeState _state = HomeState.initial();
  HomeState get state => _state;

  HomeController({
    required this.session,
    required this.depsRepo,
  });

  /// Atalho para atualizar o estado e notificar a UI.
  void _set(HomeState next) {
    _state = next;
    notifyListeners();
  }

  /// Carrega dados da Home:
  /// - login/CPF
  /// - perfil atual (se logado)
  /// - dependentes (já sem o titular)
  /// - stubs de requerimentos/comunicados
  Future<void> load() async {
    _set(_state.copyWith(loading: true));

    final logged = await session.getIsLoggedIn();
    final cpf    = await session.getSavedCpf();

    // Stubs (mantidos)
    final reqs = <RequerimentoResumo>[];
    final avisos = <ComunicadoResumo>[
      ComunicadoResumo(
        titulo: 'Manutenção programada',
        descricao: 'Sistema de autorizações ficará indisponível no domingo, 02:00–04:00.',
        data: DateTime.now(),
      ),
      ComunicadoResumo(
        titulo: 'Novo canal de atendimento',
        descricao: 'WhatsApp do setor de benefícios atualizado.',
        data: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    // Perfil + dependentes reais
    var prof = logged ? await Session.getProfile() : null;
    List<Dependent> deps = const [];

    if (logged && prof != null) {
      try {
        final all = await depsRepo.listByMatricula(prof.id);
        deps = removeTitularFromList(prof, all); // util centralizado
      } catch (_) {
        deps = const [];
      }
    }

    _set(_state.copyWith(
      loading: false,
      isLoggedIn: logged,
      cpf: cpf,
      profile: prof,
      dependents: deps,
      reqs: reqs,
      comunicados: avisos,
    ));
  }
}
