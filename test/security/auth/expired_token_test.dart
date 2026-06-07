import 'package:akshara_erp/core/auth/jwt_decoder.dart';
import 'package:akshara_erp/core/auth/jwt_validator.dart';
import 'package:akshara_erp/core/network/interceptors/auth_interceptor.dart';
import 'package:akshara_erp/features/auth/auth_token_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Expired token security', () {
    final validator = JwtValidator();

    test('validator rejects expired JWT', () {
      final token = JwtDecoder.buildMockToken(
        subject: 'user_001',
        tenantId: 'tenant_001',
        ttl: const Duration(minutes: -10),
      );

      expect(validator.validate(token).isValid, isFalse);
    });

    test('interceptor rejects expired JWT before attach', () async {
      final tokens = AuthTokens(
        accessToken: JwtDecoder.buildMockToken(
          subject: 'user_001',
          tenantId: 'tenant_001',
          ttl: const Duration(minutes: -10),
        ),
        refreshToken: '',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      final interceptor = AuthInterceptor(
        tokenAccessor: () => tokens,
        allowAnonymous: false,
        jwtValidator: validator,
        refreshCallback: null,
      );

      final options = RequestOptions(path: '/secure');
      late DioException? rejection;
      interceptor.onRequest(
        options,
        _RejectHandler((err) => rejection = err),
      );
      await Future<void>.delayed(Duration.zero);

      expect(rejection, isNotNull);
      expect(rejection!.message, contains('Invalid access token'));
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
