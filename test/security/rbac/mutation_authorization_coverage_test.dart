import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_validator.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mutation authorization coverage', () {
    test('finance admin without approveRefunds fails approve permission check', () {
      final rbac = RbacService(
        UserPermissions(
          role: ErpRole.financeAdmin,
          permissionSet: PermissionSet.from(const [
            Permission.viewFinance,
            Permission.manageFinance,
          ]),
        ),
      );

      expect(rbac.hasApprovePermission(Permission.approveRefunds), isFalse);
      expect(
        () => assertApprovePermission(rbac, Permission.approveRefunds),
        throwsA(isA<Exception>()),
      );
    });

    test('principal passes approveRefunds permission check', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.superAdmin));
      expect(rbac.hasApprovePermission(Permission.approveRefunds), isTrue);
      expect(
        () => assertApprovePermission(rbac, Permission.approveRefunds),
        returnsNormally,
      );
    });

    test('registry approveRefund maps to approveRefunds permission', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.superAdmin));
      expect(
        () => assertApprovePermission(rbac, Permission.approveRefunds),
        returnsNormally,
      );
    });
  });
}
