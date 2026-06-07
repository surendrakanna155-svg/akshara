import 'package:akshara_erp/core/auth/jwt_decoder.dart';
import 'package:akshara_erp/core/auth/jwt_validator.dart';
import 'package:akshara_erp/core/network/interceptors/auth_interceptor.dart';
import 'package:akshara_erp/features/auth/auth_token_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Invalid JWT claims security', () {
    final validator = JwtValidator();

    test('rejects token with missing sub', () {
      final token = JwtDecoder.buildMockToken(
        subject: '',
        tenantId: 'tenant_001',
      );

      expect(validator.validate(token).failureReason, 'missing_sub');
    });

    test('rejects token with tenant mismatch', () {
      final token = JwtDecoder.buildMockToken(
        subject: 'user_001',
        tenantId: 'tenant_a',
      );

      final result = validator.validate(token, expectedTenantId: 'tenant_b');
      expect(result.failureReason, 'tenant_mismatch');
    });

    test('interceptor rejects invalid JWT claims', () async {
      final tokens = AuthTokens(
        accessToken: JwtDecoder.buildMockToken(
          subject: '',
          tenantId: 'tenant_001',
        ),
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final interceptor = AuthInterceptor(
        tokenAccessor: () => tokens,
        allowAnonymous: false,
        jwtValidator: validator,
      );

      final options = RequestOptions(path: '/secure');
      late DioException? rejection;
      interceptor.onRequest(
        options,
        _RejectHandler((err) => rejection = err),
      );
      await Future<void>.delayed(Duration.zero);

      expect(rejection, isNotNull);
      expect(rejection!.message, contains('missing_sub'));
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
