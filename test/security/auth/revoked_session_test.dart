import 'package:akshara_erp/core/auth/jwt_decoder.dart';
import 'package:akshara_erp/core/auth/secure_storage_backend.dart';
import 'package:akshara_erp/core/auth/token_revocation_service.dart';
import 'package:akshara_erp/core/network/interceptors/auth_interceptor.dart';
import 'package:akshara_erp/features/auth/auth_token_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Revoked session security', () {
    late TokenRevocationService revocationService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      revocationService = TokenRevocationService(
        storage: PreferencesStorageBackend(prefs),
      );
    });

    test('revocation service tracks revoked session ids', () async {
      await revocationService.revokeSession('session_revoked', notifyServer: false);

      expect(await revocationService.isSessionRevoked('session_revoked'), isTrue);
      expect(await revocationService.isSessionRevoked('session_active'), isFalse);
    });

    test('interceptor rejects revoked session token', () async {
      await revocationService.revokeSession('session_revoked', notifyServer: false);

      final tokens = AuthTokens(
        accessToken: JwtDecoder.buildMockToken(
          subject: 'user_001',
          tenantId: 'tenant_001',
        ),
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        sessionId: 'session_revoked',
      );

      final interceptor = AuthInterceptor(
        tokenAccessor: () => tokens,
        allowAnonymous: false,
        revocationService: revocationService,
      );

      final options = RequestOptions(path: '/secure');
      late DioException? rejection;
      interceptor.onRequest(
        options,
        _RejectHandler((err) => rejection = err),
      );
      await Future<void>.delayed(Duration.zero);

      expect(rejection, isNotNull);
      expect(rejection!.message, 'Session revoked');
    });
  });
}

class _RejectHandler extends RequestInterceptorHandler {
  _RejectHandler(this.onReject);

  final void Function(DioException error) onReject;

  @override
  void reject(DioException err, [bool callFollowingErrorInterceptor = true]) {
    onReject(err);
  }
}
