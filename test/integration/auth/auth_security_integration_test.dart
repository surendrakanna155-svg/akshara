import 'package:akshara_erp/core/auth/auth_session_manager.dart';
import 'package:akshara_erp/core/auth/jwt_decoder.dart';
import 'package:akshara_erp/core/auth/refresh_token_rotation_tracker.dart';
import 'package:akshara_erp/core/auth/secure_storage_backend.dart';
import 'package:akshara_erp/core/auth/session_expiration_policy.dart';
import 'package:akshara_erp/core/auth/session_metadata.dart';
import 'package:akshara_erp/core/auth/token_revocation_service.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_token_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Auth security integration', () {
    late AuthSessionManager sessionManager;
    late TokenRevocationService revocationService;
    late RefreshTokenRotationTracker rotationTracker;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      revocationService = TokenRevocationService(
        storage: PreferencesStorageBackend(prefs),
      );
      rotationTracker = RefreshTokenRotationTracker();
      sessionManager = AuthSessionManager(
        rotationTracker: rotationTracker,
        expirationPolicy: const SessionExpirationPolicy(
          maxSessionAge: Duration(days: 1),
          idleTimeout: Duration(hours: 1),
        ),
        revocationService: revocationService,
      );
    });

    tearDown(() => sessionManager.dispose());

    AuthTokens jwtTokens({Duration ttl = const Duration(hours: 1)}) {
      final expiresAt = DateTime.now().add(ttl);
      return AuthTokens(
        accessToken: JwtDecoder.buildMockToken(
          subject: 'staff_001',
          tenantId: 'tenant_001',
          role: ErpRole.superAdmin.name,
          ttl: ttl,
        ),
        refreshToken: 'refresh_active',
        expiresAt: expiresAt,
        sessionId: 'session_active',
        tokenFamilyId: 'family_1',
      );
    }

    test('restores valid JWT session with metadata touch', () async {
      final tokens = jwtTokens();
      rotationTracker.seed(tokens);

      final result = await sessionManager.restoreSession(
        tokens: tokens,
        claims: AuthClaims.demoForRole(erpRole: ErpRole.superAdmin),
        sessionMetadata: DeviceSessionMetadata(
          sessionStartedAt: DateTime.now(),
          lastActivityAt: DateTime.now(),
          sessionId: tokens.sessionId,
        ),
      );

      expect(result.isValid, isTrue);
      expect(result.wasRefreshed, isFalse);
    });

    test('rejects revoked session on restore', () async {
      final tokens = jwtTokens();
      await revocationService.revokeSession('session_active', notifyServer: false);

      final result = await sessionManager.restoreSession(
        tokens: tokens,
        claims: AuthClaims.demoForRole(erpRole: ErpRole.superAdmin),
      );

      expect(result.isValid, isFalse);
      expect(result.wasRevoked, isTrue);
    });

    test('rejects idle-expired session metadata', () async {
      final tokens = jwtTokens();
      final metadata = DeviceSessionMetadata(
        sessionStartedAt: DateTime.now().subtract(const Duration(days: 2)),
        lastActivityAt: DateTime.now().subtract(const Duration(hours: 2)),
        sessionId: tokens.sessionId,
      );

      final result = await sessionManager.restoreSession(
        tokens: tokens,
        claims: AuthClaims.demoForRole(erpRole: ErpRole.superAdmin),
        sessionMetadata: metadata,
      );

      expect(result.isValid, isFalse);
      expect(result.wasPolicyExpired, isTrue);
    });

    test('rejects refresh token reuse', () async {
      final first = jwtTokens();
      final rotated = first.copyWith(refreshToken: 'refresh_rotated');

      rotationTracker.seed(first);
      rotationTracker.recordRotation(previous: first, next: rotated);

      final result = await sessionManager.restoreSession(
        tokens: first,
        claims: AuthClaims.demoForRole(erpRole: ErpRole.superAdmin),
      );

      expect(result.isValid, isFalse);
      expect(result.wasReuseDetected, isTrue);
    });
  });
}
