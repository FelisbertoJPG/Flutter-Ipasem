import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _kIsLoggedIn = 'is_logged_in';
  static const _kSavedCpf   = 'saved_cpf';
  static const _kAuthToken  = 'auth_token';

  Future<bool> getIsLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsLoggedIn) ?? false;
    // por enquanto: visitante padrão (false)
  }

  Future<String?> getSavedCpf() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSavedCpf);
  }

  Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLoggedIn, value);
  }

  Future<void> saveCpf(String cpf) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSavedCpf, cpf);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSavedCpf);
    await prefs.remove(_kAuthToken);
    await prefs.setBool(_kIsLoggedIn, false);
  }
}
