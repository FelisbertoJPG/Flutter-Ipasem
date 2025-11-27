// lib/services/card_token_store.dart
import 'package:shared_preferences/shared_preferences.dart';

class CardTokenStore {
  static String _key(int matricula, int dep) => 'card_dbtoken_${matricula}_$dep';
  static String _expKey(int matricula, int dep) => 'card_dbtoken_exp_${matricula}_$dep';

  static Future<void> save(int matricula, int dep, int token, int expEpoch) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_key(matricula, dep), token);
    await p.setInt(_expKey(matricula, dep), expEpoch);
  }

  static Future<(int? token, int? expEpoch)> read(int matricula, int dep) async {
    final p = await SharedPreferences.getInstance();
    final t = p.getInt(_key(matricula, dep));
    final e = p.getInt(_expKey(matricula, dep));
    return (t, e);
  }

  static Future<void> clear(int matricula, int dep) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key(matricula, dep));
    await p.remove(_expKey(matricula, dep));
  }
}
