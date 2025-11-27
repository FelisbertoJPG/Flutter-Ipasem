import 'package:flutter/foundation.dart';


// IMPORTANTE: use SEMPRE este shim para referenciar o HomeState/Controller.
// Não importe também 'home_state.dart' direto em outros arquivos.
import '../../common/core/models.dart';
import '../../common/data/session_store.dart';
import '../../common/models/dependent.dart';
import '../../common/repositories/comunicados_repository.dart';
import '../../common/repositories/dependents_repository.dart';
import '../../common/services/dependent_utils.dart';
import '../../common/services/session.dart';
import 'home_state_controller.dart';          // reexporta HomeState

/// Controlador da Home.
/// - Carrega status de login, CPF salvo e perfil atual.
/// - Busca dependentes via repo e remove o titular da contagem/exibição.
/// - Busca comunicados via repositório dedicado.
/// - Expõe um `HomeState` que a tela observa (AnimatedBuilder/ChangeNotifier).
class HomeController extends ChangeNotifier {
  final SessionStore session;
  final DependentsRepository depsRepo;
  final ComunicadosRepository comRepo;

  HomeState _state = HomeState.initial();
  HomeState get state => _state;

  HomeController({
    required this.session,
    required this.depsRepo,
    required this.comRepo,
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
  /// - requerimentos (stub por enquanto)
  /// - comunicados (via repo; se vazio, o front mostra "Sem comunicados Publicados")
  Future<void> load() async {
    _set(_state.copyWith(loading: true));

    final logged = await session.getIsLoggedIn();
    final cpf    = await session.getSavedCpf();

    // Stubs de requerimentos mantidos (preencha conforme evoluir)
    final reqs = <RequerimentoResumo>[];

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

    // Comunicados via repositório (públicos)
    List<ComunicadoResumo> avisos = const [];
    try {
      avisos = await comRepo.listPublicados(limit: 10);
    } catch (_) {
      avisos = const [];
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
