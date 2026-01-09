// lib/backend/controller/login_dependente_controller.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../common/config/app_config.dart';
import '../../common/models/profile.dart';
import '../../common/repositories/auth_repository.dart';
import '../../common/services/session.dart';
import '../config/validators.dart';
import '../exception/app_exception.dart';
import 'login_controller.dart'; // para reaproveitar kIsLoggedIn

enum DependentLoginOutcome { success, error }

class DependentLoginController {
  final AuthRepository repo;
  final AppConfig? appConfig;

  /// Estado observado pela UI (spinner do botão)
  final loading = ValueNotifier<bool>(false);

  /// Payload da etapa 1 (usado na etapa 2 – escolher vínculo)
  Profile? _profile;
  List<Map<String, dynamic>> _vinculos = const [];

  /// A tela pode ler estes getters depois do submit()
  Profile? get profile => _profile;
  List<Map<String, dynamic>> get vinculos => List.unmodifiable(_vinculos);
  bool get hasMultipleVinculos => _vinculos.length > 1;

  DependentLoginController({
    required this.repo,
    this.appConfig,
  });

  /// Passo 1: envia CPF + senha do dependente.
  ///
  /// - `rawCpfDigits`: apenas dígitos (sem máscara).
  /// - `password`: senha do dependente.
  ///
  /// Retorno:
  ///   - (success, null)  -> credenciais ok; leia [profile] e [vinculos].
  ///   - (error, mensagem)-> erro de validação ou backend.
  Future<(DependentLoginOutcome, String?)> submit({
    required String rawCpfDigits,
    required String password,
  }) async {
    // Valida CPF (mesmo helper usado no login principal)
    final cpfErr = validateCpfDigits(rawCpfDigits);
    if (cpfErr != null) {
      return (DependentLoginOutcome.error, cpfErr);
    }

    // Valida senha com a mesma regra do login principal
    final pwdErr = validatePassword(
      password,
      minLen: appConfig?.params.passwordMinLength ?? 4,
    );
    if (pwdErr != null) {
      return (DependentLoginOutcome.error, pwdErr);
    }

    // IMPORTANTE:
    // No curl que funcionou você usou CPF "051.068.460-21".
    // Aqui formatamos os 11 dígitos para esse padrão antes de enviar.
    String cpfForApi = rawCpfDigits;
    if (rawCpfDigits.length == 11) {
      cpfForApi =
      '${rawCpfDigits.substring(0, 3)}.'
          '${rawCpfDigits.substring(3, 6)}.'
          '${rawCpfDigits.substring(6, 9)}-'
          '${rawCpfDigits.substring(9)}';
    }

    loading.value = true;

    try {
      // Agora o repo.loginDependente devolve (Profile, List<Map<String,dynamic>>)
      final (profile, vinculos) = await repo.loginDependente(
        cpfForApi,
        password,
      );

      // Guarda para a etapa 2 (escolher vínculo)
      _profile = profile;
      _vinculos = vinculos;

      // NÃO grava sessão aqui. Isso será feito no finishLoginWithVinculo().
      return (DependentLoginOutcome.success, null);
    } on AppException catch (e) {
      return (DependentLoginOutcome.error, e.message);
    } catch (_) {
      return (
      DependentLoginOutcome.error,
      'Falha no login do dependente.',
      );
    } finally {
      loading.value = false;
    }
  }

  /// Passo 2: finaliza o login depois de o usuário escolher o vínculo.
  ///
  /// Aqui montamos um Profile "inteligente":
  ///  - id          = matrícula do titular escolhido
  ///  - idDependente>0 => contexto de DEPENDENTE
  Future<void> finishLoginWithVinculo(Map<String, dynamic> vinculo) async {
    final p = _profile;
    if (p == null) {
      return;
    }

    int _toInt(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    // Matrícula do titular escolhida no combo
    final chosenIdMatricula = _toInt(
      vinculo['idmatricula'] ?? vinculo['matricula'],
      p.id,
    );

    // Se o backend mandar iddependente no vínculo, usamos; senão
    // usamos o idDependente do profile (que veio da etapa 1).
    final int? chosenDepId = vinculo.containsKey('iddependente')
        ? _toInt(vinculo['iddependente'], p.idDependente ?? 0)
        : p.idDependente;

    // Monta um profile atualizado com a matrícula do titular
    // e o id do dependente (>0). Esse é o "identificador inteligente".
    final updated = p.copyWith(
      id: chosenIdMatricula,
      idDependente: chosenDepId,
    );

    await Session.saveLogin(updated, token: 'dev');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LoginController.kIsLoggedIn, true);
  }

  void dispose() {
    loading.dispose();
  }
}
