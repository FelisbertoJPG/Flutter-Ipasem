import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/validators.dart';
import '../models/profile.dart';
import '../repositories/auth_repository.dart';
import '../services/session.dart';
import '../core/app_exception.dart';

enum LoginOutcome { success, guest, error, none }

class LoginController {
  // Chaves compartilhadas com a UI (mantidas)
  static const kSavedCpf     = 'saved_cpf';
  static const kAuthToken    = 'auth_token';
  static const kIsLoggedIn   = 'is_logged_in';
  static const kStaySignedIn = 'stay_signed_in';

  final AuthRepository repo;
  final AppConfig? appConfig;

  // estado observável p/ UI
  final loading = ValueNotifier<bool>(false);
  final rememberCpf = ValueNotifier<bool>(true);
  final staySignedIn = ValueNotifier<bool>(true);

  String _savedCpf = '';
  String get savedCpf => _savedCpf;

  LoginController({required this.repo, this.appConfig});

  /// Lê preferências, atualiza flags e retorna se deve auto-entrar na shell.
  Future<bool> init() async {
    final p = await SharedPreferences.getInstance();
    _savedCpf = p.getString(kSavedCpf) ?? '';
    rememberCpf.value = _savedCpf.isNotEmpty;
    staySignedIn.value = p.getBool(kStaySignedIn) ?? true;
    final isLogged = p.getBool(kIsLoggedIn) ?? false;
    return staySignedIn.value && isLogged;
  }

  /// URL de "Primeiro acesso", lendo do AppConfig se existir.
  String get firstAccessUrl =>
      appConfig?.params.firstAccessUrl ??
          'https://assistweb.ipasemnh.com.br/site/recuperar-senha';

  /// Submit de credenciais. Retorna (outcome, message).
  Future<(LoginOutcome, String?)> submit({
    required String rawCpfDigits,
    required String password,
  }) async {
    // validações (segurança extra; a UI também valida)
    final cpfErr = validateCpfDigits(rawCpfDigits);
    if (cpfErr != null) return (LoginOutcome.error, cpfErr);
    final pwdErr =
    validatePassword(password, minLen: appConfig?.params.passwordMinLength ?? 4);
    if (pwdErr != null) return (LoginOutcome.error, pwdErr);

    final prefs = await SharedPreferences.getInstance();
    loading.value = true;
    try {
      // preferências
      if (rememberCpf.value) {
        await prefs.setString(kSavedCpf, rawCpfDigits);
      } else {
        await prefs.remove(kSavedCpf);
      }
      await prefs.setBool(kStaySignedIn, staySignedIn.value);

      // login
      final Profile profile = await repo.login(
        // envia formatado XXX.XXX.XXX-XX
        _fmtCpf(rawCpfDigits),
        password,
      );

      await Session.saveLogin(profile, token: 'dev');
      await prefs.setBool(kIsLoggedIn, true);
      return (LoginOutcome.success, null);
    } on AppException catch (e) {
      return (LoginOutcome.error, e.message);
    } on DioException catch (e) {
      String msg = 'Falha no login';
      final data = e.response?.data;
      if (data is Map && data['error'] is Map && data['error']['message'] is String) {
        msg = data['error']['message'] as String;
      } else if ((e.message ?? '').isNotEmpty) {
        msg = e.message!;
      }
      return (LoginOutcome.error, msg);
    } catch (_) {
      return (LoginOutcome.error, 'Falha no login');
    } finally {
      loading.value = false;
    }
  }

  /// Fluxo de visitante.
  Future<(LoginOutcome, String?)> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kAuthToken);
    await prefs.setBool(kIsLoggedIn, false);
    await prefs.setBool('visitor_consent_accepted', true);
    return (LoginOutcome.guest, null);
  }

  void dispose() {
    loading.dispose();
    rememberCpf.dispose();
    staySignedIn.dispose();
  }

  // util local (sem depender de formatters na UI)
  String _fmtCpf(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.length != 11) return digits;
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
    // (ou use seu fmtCpf se preferir importar)
  }
}
