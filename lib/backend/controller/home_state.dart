// lib/controllers/home_state.dart


import '../../common/core/models.dart';
import '../../common/models/dependent.dart';
import '../../common/models/profile.dart';

class HomeState {
  final bool loading;
  final bool isLoggedIn;
  final String? cpf;
  final Profile? profile;
  final List<Dependent> dependents;
  final List<RequerimentoResumo> reqs;
  final List<ComunicadoResumo> comunicados;

  const HomeState({
    required this.loading,
    required this.isLoggedIn,
    required this.cpf,
    required this.profile,
    required this.dependents,
    required this.reqs,
    required this.comunicados,
  });

  factory HomeState.initial() => const HomeState(
    loading: true,
    isLoggedIn: false,
    cpf: null,
    profile: null,
    dependents: <Dependent>[],
    reqs: <RequerimentoResumo>[],
    comunicados: <ComunicadoResumo>[],
  );

  HomeState copyWith({
    bool? loading,
    bool? isLoggedIn,
    String? cpf,
    Profile? profile,
    List<Dependent>? dependents,
    List<RequerimentoResumo>? reqs,
    List<ComunicadoResumo>? comunicados,
  }) {
    return HomeState(
      loading: loading ?? this.loading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      cpf: cpf ?? this.cpf,
      profile: profile ?? this.profile,
      dependents: dependents ?? this.dependents,
      reqs: reqs ?? this.reqs,
      comunicados: comunicados ?? this.comunicados,
    );
  }
}
