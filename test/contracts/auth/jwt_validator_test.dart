import 'package:akshara_erp/core/auth/jwt_decoder.dart';
import 'package:akshara_erp/core/auth/jwt_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JwtValidator', () {
    final validator = JwtValidator(clockSkewTolerance: const Duration(seconds: 60));

    test('accepts valid JWT claims', () {
      final token = JwtDecoder.buildMockToken(
        subject: 'user_001',
        tenantId: 'tenant_001',
        ttl: const Duration(hours: 1),
      );

      final result = validator.validate(token);

      expect(result.isValid, isTrue);
      expect(result.failureReason, isNull);
    });

    test('rejects empty token', () {
      final result = validator.validate('');
      expect(result.isValid, isFalse);
      expect(result.failureReason, 'empty_token');
    });

    test('rejects invalid format', () {
      final result = validator.validate('not-a-jwt');
      expect(result.isValid, isFalse);
      expect(result.failureReason, 'invalid_format');
    });

    test('rejects missing tenant_id', () {
      final token = JwtDecoder.buildMockToken(
        subject: 'user_001',
        tenantId: '',
      );
      final result = validator.validate(token);
      expect(result.isValid, isFalse);
      expect(result.failureReason, 'missing_tenant_id');
    });

    test('rejects expired token beyond clock skew', () {
      final token = JwtDecoder.buildMockToken(
        subject: 'user_001',
        tenantId: 'tenant_001',
        ttl: const Duration(minutes: -5),
      );

      final result = validator.validate(token);
      expect(result.isValid, isFalse);
      expect(result.failureReason, 'expired');
    });

    test('rejects tenant mismatch', () {
      final token = JwtDecoder.buildMockToken(
        subject: 'user_001',
        tenantId: 'tenant_a',
      );

      final result = validator.validate(
        token,
        expectedTenantId: 'tenant_b',
      );

      expect(result.isValid, isFalse);
      expect(result.failureReason, 'tenant_mismatch');
    });
  });
}
