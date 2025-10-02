// lib/controllers/login_controller.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/validators.dart';
import '../core/app_exception.dart';
import '../models/profile.dart';
import '../repositories/auth_repository.dart';
import '../services/session.dart';
import '../services/secure_store.dart'; // createSecureStore(), ISecureStore

enum LoginOutcome { success, guest, error, none }

class LoginController {
  // Chaves de preferências (não guardar senha aqui!)
  static const kSavedCpf     = 'saved_cpf';
  static const kAuthToken    = 'auth_token';
  static const kIsLoggedIn   = 'is_logged_in';
  static const kStaySignedIn = 'stay_signed_in';

  final AuthRepository repo;
  final AppConfig? appConfig;
  final ISecureStore secureStore;

  // estado observado pela UI
  final loading       = ValueNotifier<bool>(false);
  final rememberCpf   = ValueNotifier<bool>(true);
  final staySignedIn  = ValueNotifier<bool>(true);

  String _savedCpf = '';
  String _savedPassword = '';

  String get savedCpf => _savedCpf;
  String get savedPassword => _savedPassword;

  LoginController({
    required this.repo,
    this.appConfig,
    ISecureStore? secureStore,
  }) : secureStore = secureStore ?? createSecureStore();

  /// Lê preferências e popula flags/campos para a UI.
  /// Não faz auto-login; apenas deixa os campos preenchidos.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _savedCpf = prefs.getString(kSavedCpf) ?? '';
    rememberCpf.value = _savedCpf.isNotEmpty;

    staySignedIn.value = prefs.getBool(kStaySignedIn) ?? true;

    // senha só se "manter login" estiver ativo (no Web retornará null)
    _savedPassword = staySignedIn.value
        ? (await secureStore.readPassword()) ?? ''
        : '';
  }

  /// URL de “Primeiro acesso”
  String get firstAccessUrl =>
      appConfig?.params.firstAccessUrl ??
          'https://assistweb.ipasemnh.com.br/site/recuperar-senha';

  /// Envia credenciais. Retorna (resultado, mensagemDeErroOpcional).
  Future<(LoginOutcome, String?)> submit({
    required String rawCpfDigits,
    required String password,
  }) async {
    // Validações extras (a UI já valida também)
    final cpfErr = validateCpfDigits(rawCpfDigits);
    if (cpfErr != null) return (LoginOutcome.error, cpfErr);

    final pwdErr = validatePassword(
      password,
      minLen: appConfig?.params.passwordMinLength ?? 4,
    );
    if (pwdErr != null) return (LoginOutcome.error, pwdErr);

    final prefs = await SharedPreferences.getInstance();
    loading.value = true;

    try {
      // Preferências leves
      if (rememberCpf.value) {
        await prefs.setString(kSavedCpf, rawCpfDigits);
      } else {
        await prefs.remove(kSavedCpf);
      }
      await prefs.setBool(kStaySignedIn, staySignedIn.value);

      // Senha segura (Keychain/Keystore). No Web: no-op (não salva).
      if (staySignedIn.value) {
        await secureStore.writePassword(password);
      } else {
        await secureStore.deletePassword();
      }

      // Chamada de login
      final Profile profile = await repo.login(_fmtCpf(rawCpfDigits), password);

      // Sessão persistida
      await Session.saveLogin(profile, token: 'dev');
      await prefs.setBool(kIsLoggedIn, true);

      return (LoginOutcome.success, null);
    } on AppException catch (e) {
      return (LoginOutcome.error, e.message);
    } on DioException catch (e) {
      String msg = 'Falha no login';
      final data = e.response?.data;
      if (data is Map &&
          data['error'] is Map &&
          data['error']['message'] is String) {
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
    // Por segurança, não mantemos senha salva ao entrar como visitante.
    await secureStore.deletePassword();
    return (LoginOutcome.guest, null);
  }

  void dispose() {
    loading.dispose();
    rememberCpf.dispose();
    staySignedIn.dispose();
  }

  // Helpers
  String _fmtCpf(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.length != 11) return digits;
    return '${d.substring(0,3)}.${d.substring(3,6)}.${d.substring(6,9)}-${d.substring(9)}';
  }
}
