import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento de tokens de sesión en Keychain (iOS) / Keystore (Android).
/// Regla OWASP: no persistir tokens en texto plano ni en SharedPreferences.
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyAccess = 'erp_access_token';
  static const _keyRefresh = 'erp_refresh_token';

  Future<String?> get accessToken => _storage.read(key: _keyAccess);

  Future<String?> get refreshToken => _storage.read(key: _keyRefresh);

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _keyAccess, value: access);
    await _storage.write(key: _keyRefresh, value: refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
  }
}
