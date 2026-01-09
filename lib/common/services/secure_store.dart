// lib/services/secure_store.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Chaves centralizadas para evitar typos
class SecureKeys {
  static const savedPassword = 'saved_password';
}

abstract class ISecureStore {
  Future<void> writePassword(String password);
  Future<String?> readPassword();
  Future<void> deletePassword();
}

/// Implementação real (Android/iOS/macOS)
class SecureStore implements ISecureStore {
  // Pode customizar opções por plataforma se quiser
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> writePassword(String password) async {
    await _storage.write(key: SecureKeys.savedPassword, value: password);
  }

  @override
  Future<String?> readPassword() async {
    return _storage.read(key: SecureKeys.savedPassword);
  }

  @override
  Future<void> deletePassword() async {
    await _storage.delete(key: SecureKeys.savedPassword);
  }
}

/// Implementação nula para Web (não persistimos senha)
class SecureStoreWeb implements ISecureStore {
  @override
  Future<void> writePassword(String _) async {}
  @override
  Future<String?> readPassword() async => null;
  @override
  Future<void> deletePassword() async {}
}

/// Factory simples
ISecureStore createSecureStore() {
  if (kIsWeb) return SecureStoreWeb();
  return SecureStore();
}
