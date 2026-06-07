import 'package:akshara_erp/core/auth/jwt_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JwtDecoder', () {
    test('decodes mock token claims', () {
      final token = JwtDecoder.buildMockToken(
        subject: 'user_123',
        tenantId: 'tenant_a',
        schoolId: 'school_b',
        organizationId: 'org_c',
        role: 'superAdmin',
        ttl: const Duration(hours: 2),
      );

      final claims = jwtDecoder.decode(token);
      expect(claims, isNotNull);
      expect(claims!.subject, 'user_123');
      expect(claims.tenantId, 'tenant_a');
      expect(claims.schoolId, 'school_b');
      expect(claims.organizationId, 'org_c');
      expect(claims.role, 'superAdmin');
      expect(claims.isExpired, isFalse);
    });

    test('detects expired token', () {
      final token = JwtDecoder.buildMockToken(
        subject: 'user_expired',
        tenantId: 'tenant_a',
        ttl: const Duration(seconds: -10),
      );
      expect(jwtDecoder.isExpired(token), isTrue);
    });
  });
}
