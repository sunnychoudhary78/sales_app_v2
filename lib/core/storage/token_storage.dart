import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'storage_keys.dart';

class TokenStorage {
  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveJwt(String token) async {
    await _storage.write(key: StorageKeys.accessToken, value: token);
  }

  Future<String?> getJwt() async {
    return _storage.read(key: StorageKeys.accessToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: StorageKeys.accessToken);
  }
}

