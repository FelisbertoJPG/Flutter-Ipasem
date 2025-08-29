import 'package:fbdb/fbdb.dart';
import '../config/env.dart';

class FirebirdService {
  static FbDb? _db;

  static Future<FbDb> open() async {
    if (_db != null) return _db!;

    // validações simples pra não conectar com env vazio
    if (Env.fbHost.isEmpty || Env.fbDatabase.isEmpty || Env.fbUser.isEmpty) {
      throw StateError('Variáveis de ambiente do Firebird não foram passadas.');
    }

    _db = await FbDb.attach(
      host: Env.fbHost,
      port: Env.fbPort,
      database: Env.fbDatabase,  // alias (IPASEMDB) ou caminho completo
      user: Env.fbUser,
      password: Env.fbPassword,
      options: FbOptions(dbCharset: 'UTF8'),
    );
    return _db!;
  }

  static Future<void> close() async {
    await _db?.detach();
    _db = null;
  }
}
