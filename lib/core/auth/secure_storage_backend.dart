import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abstraction over encrypted and plaintext key-value storage for auth secrets.
abstract class SecureStorageBackend {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Encrypted storage backed by platform secure enclaves (mobile/desktop).
class FlutterSecureStorageBackend implements SecureStorageBackend {
  FlutterSecureStorageBackend({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Plaintext [SharedPreferences] fallback for tests and web.
class PreferencesStorageBackend implements SecureStorageBackend {
  PreferencesStorageBackend(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove(key);
  }
}

/// Selects secure storage on native platforms and preferences on web/tests.
SecureStorageBackend createDefaultSecureStorageBackend(
  SharedPreferences prefs, {
  bool forcePreferences = false,
}) {
  if (forcePreferences || kIsWeb) {
    return PreferencesStorageBackend(prefs);
  }
  return FlutterSecureStorageBackend();
}
