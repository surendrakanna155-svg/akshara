import 'package:akshara_erp/core/auth/auth_session_manager.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_token_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthSessionManager', () {
    late AuthSessionManager manager;

    setUp(() {
      manager = AuthSessionManager();
    });

    tearDown(() => manager.dispose());

    test('restores valid session', () async {
      final tokens = AuthTokens.demo();
      final claims = AuthClaims.demoForRole(erpRole: ErpRole.superAdmin);

      final result = await manager.restoreSession(
        tokens: tokens,
        claims: claims,
      );

      expect(result.isValid, isTrue);
      expect(result.claims?.accessTokenExpiresAt, tokens.expiresAt);
    });

    test('marks expired session invalid without refresh callback', () async {
      final tokens = AuthTokens(
        accessToken: 'expired',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      final result = await manager.restoreSession(
        tokens: tokens,
        claims: AuthClaims.demoForRole(erpRole: ErpRole.superAdmin),
      );

      expect(result.isValid, isFalse);
      expect(result.wasExpired, isTrue);
    });

    test('builds claims from access token', () {
      final token = AuthTokens.demo();
      final claims = manager.claimsFromAccessToken(token.accessToken);
      expect(claims, isNull);
    });
  });
}
