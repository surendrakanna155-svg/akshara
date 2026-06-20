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
      final original = AuthClaims(
        userId: 'user_1',
        erpRole: ErpRole.principal,
        tenantId: 'tenant_1',
        schoolId: 'school_1',
        organizationId: 'org_1',
        permissions: const [Permission.viewFinance],
      );

      final restored = AuthClaims.fromJson(original.toJson());
      expect(restored, original);
    });

    test('multi-role: holds several roles, primary first', () {
      final claims = AuthClaims.demoForRole(
        erpRoles: [ErpRole.teacher, ErpRole.inventoryManager],
      );
      expect(claims.erpRoles, [ErpRole.teacher, ErpRole.inventoryManager]);
      expect(claims.erpRole, ErpRole.teacher); // primary
      expect(claims.hasRole(ErpRole.inventoryManager), isTrue);
      expect(claims.isMultiRole, isTrue);
    });

    test('multi-role round-trips through JSON (roles array)', () {
      final original = AuthClaims(
        userId: 'surendra',
        erpRoles: const [ErpRole.teacher, ErpRole.inventoryManager],
        tenantId: 'tenant_1',
        schoolId: 'school_1',
      );
      final restored = AuthClaims.fromJson(original.toJson());
      expect(restored, original);
      expect(restored.erpRoles, [ErpRole.teacher, ErpRole.inventoryManager]);
    });

    test('legacy single-role JSON (role key) still parses', () {
      final claims = AuthClaims.fromJson({
        'userId': 'u1',
        'role': 'principal',
        'tenantId': 't1',
      });
      expect(claims.erpRoles, [ErpRole.principal]);
      expect(claims.erpRole, ErpRole.principal);
      expect(claims.isMultiRole, isFalse);
    });

    test('duplicate roles are deduped, order preserved', () {
      final claims = AuthClaims.demoForRole(
        erpRoles: [ErpRole.teacher, ErpRole.teacher, ErpRole.inventoryManager],
      );
      expect(claims.erpRoles, [ErpRole.teacher, ErpRole.inventoryManager]);
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
