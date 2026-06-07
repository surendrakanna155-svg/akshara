import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthClaims', () {
    test('demoForRole uses demo tenant defaults', () {
      final claims = AuthClaims.demoForRole(erpRole: ErpRole.financeAdmin);
      expect(claims.erpRole, ErpRole.financeAdmin);
      expect(claims.tenantId, isNotEmpty);
      expect(claims.schoolId, isNotEmpty);
      expect(claims.isValid, isTrue);
    });

    test('round-trips through JSON', () {
      final original = const AuthClaims(
        userId: 'user_1',
        erpRole: ErpRole.principal,
        tenantId: 'tenant_1',
        schoolId: 'school_1',
        organizationId: 'org_1',
        permissions: [Permission.viewFinance],
      );

      final restored = AuthClaims.fromJson(original.toJson());
      expect(restored, original);
    });

    test('fromJson ignores unknown permission names', () {
      final claims = AuthClaims.fromJson({
        'userId': 'u1',
        'role': 'superAdmin',
        'tenantId': 't1',
        'permissions': ['viewFinance', 'unknownPermission'],
      });
      expect(claims.permissions, [Permission.viewFinance]);
    });
  });
}
