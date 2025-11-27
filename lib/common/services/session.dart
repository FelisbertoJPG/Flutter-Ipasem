// lib/services/session.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';
// lib/services/session.dart (ou um constants.dart)
class SessionKeys {
  static const staySignedIn = 'stay_signed_in';
  static const isLoggedIn   = 'is_logged_in';
}

class Session {
  // Chaves únicas em um único lugar
  static const _kSavedCpf    = 'saved_cpf';
  static const _kAuthToken   = 'auth_token';
  static const _kIsLoggedIn  = 'is_logged_in';
  static const _kProfileId   = 'profile_id';
  static const _kProfileNome = 'profile_nome';
  static const _kProfileCpf  = 'profile_cpf';
  static const _kProfileMail = 'profile_email';
  static const _kProfileMail2= 'profile_email2';

  // Salva estado de sessão e perfil
  static Future<void> saveLogin(Profile p, {String token = 'dev'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLoggedIn, true);
    await prefs.setString(_kAuthToken, token);
    await prefs.setInt(_kProfileId, p.id);
    await prefs.setString(_kProfileNome, p.nome);
    await prefs.setString(_kProfileCpf, p.cpf);
    if (p.email != null)  await prefs.setString(_kProfileMail, p.email!);
    if (p.email2 != null) await prefs.setString(_kProfileMail2, p.email2!);

    // mantém “lembrar CPF”
    final cpfDigits = p.cpf.replaceAll(RegExp(r'\D'), '');
    await prefs.setString(_kSavedCpf, cpfDigits);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAuthToken);
    await prefs.setBool(_kIsLoggedIn, false);
    // mantém _kSavedCpf intocado para “lembrar CPF”
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsLoggedIn) ?? false;
  }

  static Future<Profile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getBool(_kIsLoggedIn) ?? false) == false) return null;
    final id   = prefs.getInt(_kProfileId);
    final nome = prefs.getString(_kProfileNome);
    final cpf  = prefs.getString(_kProfileCpf);
    if (id == null || nome == null || cpf == null) return null;
    return Profile(
      id: id,
      nome: nome,
      cpf: cpf,
      email: prefs.getString(_kProfileMail),
      email2: prefs.getString(_kProfileMail2),
    );
  }
}
