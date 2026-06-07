import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shared_preferences_provider.dart';
import 'auth_repository_providers.dart';
import 'jwt_validator.dart';
import 'refresh_token_rotation_tracker.dart';
import 'secure_storage_backend.dart';
import 'session_expiration_policy.dart';
import 'session_metadata.dart';
import 'token_revocation_service.dart';

export 'jwt_validator.dart';
export 'refresh_token_rotation_tracker.dart';
export 'secure_storage_backend.dart';
export 'session_expiration_policy.dart';
export 'session_metadata.dart';
export 'token_revocation_service.dart';

const String _kSessionMetadataKey = 'auth_session_metadata_v1';

/// Secure storage backend — preferences on web, encrypted elsewhere.
final secureStorageBackendProvider = Provider<SecureStorageBackend>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return createDefaultSecureStorageBackend(prefs);
});

final jwtValidatorProvider = Provider<JwtValidator>((ref) => jwtValidator);

final refreshTokenRotationTrackerProvider =
    Provider<RefreshTokenRotationTracker>((ref) {
  return RefreshTokenRotationTracker();
});

final sessionExpirationPolicyProvider =
    Provider<SessionExpirationPolicy>((ref) => sessionExpirationPolicy);

/// Persists and restores [DeviceSessionMetadata] for idle/max-age checks.
final sessionMetadataStorageProvider = Provider<SessionMetadataStorage>((ref) {
  return SessionMetadataStorage(ref.watch(secureStorageBackendProvider));
});

final tokenRevocationServiceProvider = Provider<TokenRevocationService>((ref) {
  final remote = ref.watch(authRemoteDataSourceProvider);
  return TokenRevocationService(
    storage: ref.watch(secureStorageBackendProvider),
    onRevokeSession: (sessionId) =>
        remote.revokeSession(sessionId: sessionId),
    onLogoutAllSessions: remote.logoutAllSessions,
  );
});

/// Reads/writes session metadata to secure storage.
class SessionMetadataStorage {
  SessionMetadataStorage(this._backend);

  final SecureStorageBackend _backend;

  Future<DeviceSessionMetadata?> read() async {
    final raw = await _backend.read(_kSessionMetadataKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return DeviceSessionMetadata.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  Future<void> write(DeviceSessionMetadata metadata) async {
    await _backend.write(
      _kSessionMetadataKey,
      jsonEncode(metadata.toJson()),
    );
  }

  Future<void> clear() async {
    await _backend.delete(_kSessionMetadataKey);
  }
}
