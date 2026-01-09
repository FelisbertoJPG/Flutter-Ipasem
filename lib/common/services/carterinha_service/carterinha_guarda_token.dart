// lib/services/carterinha_guarda_token.dart
import 'package:shared_preferences/shared_preferences.dart';

/// Store canônico do dbToken da carteirinha + expiração.
///
/// Chaveada por (matrícula, dependente).
/// - Grava em SharedPreferences:
///   - card_dbtoken_{matricula}_{dep}      -> int dbToken
///   - card_dbtoken_exp_{matricula}_{dep}  -> int expEpoch (segundos)
class CardTokenStore {
  static String _key(int matricula, int dep) =>
      'card_dbtoken_${matricula}_$dep';

  static String _expKey(int matricula, int dep) =>
      'card_dbtoken_exp_${matricula}_$dep';

  /// Salva o dbToken + expiração em epoch (segundos).
  static Future<void> save(
      int matricula,
      int dep,
      int token,
      int expEpoch,
      ) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_key(matricula, dep), token);
    await p.setInt(_expKey(matricula, dep), expEpoch);
  }

  /// Lê dbToken + expiração.
  ///
  /// Retorna um record (token, expEpoch). Se não existir, ambos podem vir null.
  static Future<(int? token, int? expEpoch)> read(
      int matricula,
      int dep,
      ) async {
    final p = await SharedPreferences.getInstance();
    final t = p.getInt(_key(matricula, dep));
    final e = p.getInt(_expKey(matricula, dep));
    return (t, e);
  }

  /// Limpa qualquer valor salvo para (matrícula, dependente).
  static Future<void> clear(int matricula, int dep) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key(matricula, dep));
    await p.remove(_expKey(matricula, dep));
  }
}
