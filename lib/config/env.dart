// lib/config/env.dart
class Env {
  static const fbHost     = String.fromEnvironment('FB_HOST');                 // ex: 200.200.200.10
  static const fbPort     = int.fromEnvironment('FB_PORT', defaultValue: 3050);
  static const fbDatabase = String.fromEnvironment('FB_DB');                   // ex: IPASEMDB (alias) ou caminho
  static const fbUser     = String.fromEnvironment('FB_USER');                 // ex: SYSDBA
  static const fbPassword = String.fromEnvironment('FB_PASSWORD');             // ex: ****
}
