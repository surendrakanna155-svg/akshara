import 'dart:convert';

import 'secure_storage_backend.dart';

/// Server hook invoked when a session should be revoked remotely.
typedef RevokeSessionCallback = Future<void> Function(String sessionId);

/// Server hook invoked to revoke all sessions for the current user.
typedef LogoutAllSessionsCallback = Future<void> Function();

const String _kRevokedSessionsKey = 'auth_revoked_session_ids_v1';

/// Tracks locally revoked session IDs and notifies the auth server.
class TokenRevocationService {
  TokenRevocationService({
    required SecureStorageBackend storage,
    this.onRevokeSession,
    this.onLogoutAllSessions,
  }) : _storage = storage;

  final SecureStorageBackend _storage;
  final RevokeSessionCallback? onRevokeSession;
  final LogoutAllSessionsCallback? onLogoutAllSessions;

  Set<String> _revokedSessionIds = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final raw = await _storage.read(_kRevokedSessionsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _revokedSessionIds = {
            for (final item in decoded)
              if (item is String && item.isNotEmpty) item,
          };
        }
      } on Object {
        _revokedSessionIds = {};
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    await _storage.write(
      _kRevokedSessionsKey,
      jsonEncode(_revokedSessionIds.toList()),
    );
  }

  /// Returns `true` when [sessionId] has been revoked locally.
  Future<bool> isSessionRevoked(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) return false;
    await _ensureLoaded();
    return _revokedSessionIds.contains(sessionId);
  }

  /// Synchronous check after [ensureLoaded] has been called.
  bool isSessionRevokedSync(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return false;
    return _revokedSessionIds.contains(sessionId);
  }

  /// Preloads revoked session IDs from storage.
  Future<void> ensureLoaded() => _ensureLoaded();

  /// Revokes a single session locally and optionally on the server.
  Future<void> revokeSession(
    String sessionId, {
    bool notifyServer = true,
  }) async {
    if (sessionId.isEmpty) return;
    await _ensureLoaded();
    _revokedSessionIds.add(sessionId);
    await _persist();
    if (notifyServer) {
      await onRevokeSession?.call(sessionId);
    }
  }

  /// Revokes all sessions via server hook and clears local revocation cache.
  Future<void> revokeAllSessions({bool notifyServer = true}) async {
    if (notifyServer) {
      await onLogoutAllSessions?.call();
    }
    _revokedSessionIds = {};
    await _persist();
  }

  /// Clears all locally tracked revocations (e.g. on full logout).
  Future<void> clearLocalRevocations() async {
    _revokedSessionIds = {};
    await _persist();
  }
}
