import 'dart:convert';

import '../../core/auth/secure_storage_backend.dart';
import 'auth_token_models.dart';

/// Storage key for persisted auth tokens.
const String kAuthTokensStorageKey = 'auth_tokens_v1';

/// Reads and writes [AuthTokens] via a [SecureStorageBackend].
class TokenStorage {
  TokenStorage(this._backend);

  final SecureStorageBackend _backend;
  AuthTokens? _memoryCache;

  AuthTokens? readSync() => _memoryCache;

  Future<AuthTokens?> read() async {
    final raw = await _backend.read(kAuthTokensStorageKey);
    if (raw == null || raw.isEmpty) {
      _memoryCache = null;
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _memoryCache = null;
        return null;
      }
      final tokens = AuthTokens.fromJson(decoded);
      if (tokens.accessToken.isEmpty) {
        _memoryCache = null;
        return null;
      }
      _memoryCache = tokens;
      return tokens;
    } on Object {
      _memoryCache = null;
      return null;
    }
  }

  Future<void> write(AuthTokens tokens) async {
    _memoryCache = tokens;
    await _backend.write(
      kAuthTokensStorageKey,
      jsonEncode(tokens.toJson()),
    );
  }

  Future<void> clear() async {
    _memoryCache = null;
    await _backend.delete(kAuthTokensStorageKey);
  }
}
