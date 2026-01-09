// lib/data/consent_store.dart
import 'package:shared_preferences/shared_preferences.dart';

class ConsentStore {
  static const _kAcceptedKey = 'visitor_consent_accepted_v1';
  static const _kAcceptedAtKey = 'visitor_consent_accepted_at';

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAcceptedKey) ?? false;
    // Para “expirar” um dia, por ex., guarde _kAcceptedAtKey e compare aqui.
  }

  static Future<void> setAccepted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAcceptedKey, value);
    if (value) {
      await prefs.setInt(_kAcceptedAtKey, DateTime.now().millisecondsSinceEpoch);
    } else {
      await prefs.remove(_kAcceptedAtKey);
    }
  }
}
