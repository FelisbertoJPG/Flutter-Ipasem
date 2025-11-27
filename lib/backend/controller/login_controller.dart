// lib/controllers/login_controller.dart
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // necessário para ValueNotifier

import '../../common/config/app_config.dart';
import '../../common/core/app_exception.dart';
import '../../common/core/validators.dart';
import '../../common/models/profile.dart';
import '../../common/repositories/auth_repository.dart';
import '../../common/services/secure_store.dart';
import '../../common/services/session.dart';


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
  final loading      = ValueNotifier<bool>(false);
  final rememberCpf  = ValueNotifier<bool>(true);
  final staySignedIn = ValueNotifier<bool>(true);

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
      // Preferências leves (CPF + flag)
      if (rememberCpf.value) {
        await prefs.setString(kSavedCpf, rawCpfDigits);
      } else {
        await prefs.remove(kSavedCpf);
      }
      await prefs.setBool(kStaySignedIn, staySignedIn.value);

      // 1) Chamada de login
      final Profile profile = await repo.login(_fmtCpf(rawCpfDigits), password);

      // 2) Se deu certo, então persiste a senha (ou apaga)
      if (staySignedIn.value) {
        await secureStore.writePassword(password);
        _savedPassword = password; // mantém em memória também
      } else {
        await secureStore.deletePassword();
        _savedPassword = '';
      }

      // 3) Sessão persistida
      await Session.saveLogin(profile, token: 'dev');
      await prefs.setBool(kIsLoggedIn, true);

      // 4) Atualiza CPF em memória (útil para auto-login subsequente)
      _savedCpf = rawCpfDigits;

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
    await prefs.setBool('visitor_consent_accepted_v1', true); // <- padroniza com ConsentStore
    // Por segurança, não mantemos senha salva ao entrar como visitante.
    await secureStore.deletePassword();
    _savedPassword = '';
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

  /// Salva as flags imediatamente (opcional: para persistir ao tocar no checkbox).
  Future<void> setStaySignedIn(bool v) async {
    staySignedIn.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kStaySignedIn, v);
    if (!v) {
      // Se desativou, apaga a senha do secure store.
      await secureStore.deletePassword();
      _savedPassword = '';
    }
  }

  /// Mantém o CPF em sincronia com a intenção do usuário.
  Future<void> setRememberCpf(bool v) async {
    rememberCpf.value = v;
    final prefs = await SharedPreferences.getInstance();
    if (!v) await prefs.remove(kSavedCpf);
  }

  /// Tenta logar automaticamente usando CPF + senha salvos com "Manter login".
  /// Retorna true se logou; false se faltou dado, offline ou falhou.
  Future<bool> tryAutoLoginWithSavedPassword() async {
    // Garante que init() já populou savedCpf/savedPassword/staySignedIn
    if (!staySignedIn.value) return false;
    if (_savedCpf.isEmpty || _savedPassword.isEmpty) return false;

    try {
      final profile = await repo.login(_fmtCpf(_savedCpf), _savedPassword);
      await Session.saveLogin(profile, token: 'dev'); // se o login devolver token, use-o aqui
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kIsLoggedIn, true);
      return true;
    } catch (_) {
      // Não derruba a experiência: apenas falhou o auto-login
      return false;
    }
  }
}
