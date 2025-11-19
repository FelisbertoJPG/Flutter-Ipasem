// lib/services/card_token_cache.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CardTokenCache {
  static String _key(int matricula, String iddep) =>
      'card_token_${matricula}_$iddep';

  static Future<void> save({
    required int matricula,
    required String iddep,
    required int dbToken,
    required int expiresAtEpoch,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'db_token': dbToken,
      'expires_at_epoch': expiresAtEpoch,
      'matricula': matricula,
      'iddep': iddep,
    };
    await prefs.setString(_key(matricula, iddep), jsonEncode(map));
  }

  static Future<Map<String, dynamic>?> load({
    required int matricula,
    required String iddep,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(matricula, iddep));
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> clear({
    required int matricula,
    required String iddep,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(matricula, iddep));
  }
}
