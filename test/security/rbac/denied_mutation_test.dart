import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_validator.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mutation permission validator', () {
    test('assertManagePermission passes when grant exists', () {
      final rbac = RbacService(
        UserPermissions.forRole(ErpRole.financeAdmin),
      );

      expect(
        () => assertManagePermission(rbac, Permission.manageFinance),
        returnsNormally,
      );
    });

    test('assertManagePermission throws forbidden when grant missing', () {
      final rbac = RbacService(
        UserPermissions(
          role: ErpRole.financeAdmin,
          permissionSet: PermissionSet.from(const [
            Permission.viewFinance,
          ]),
        ),
      );

      expect(
        () => assertManagePermission(rbac, Permission.manageFinance),
        throwsA(
          isA<ApiFailureException>().having(
            (e) => e.failure.type,
            'type',
            ApiFailureType.forbidden,
          ),
        ),
      );
    });

    test('assertApprovePermission rejects non-approve permission enum', () {
      final rbac = RbacService(
        UserPermissions.forRole(ErpRole.principal),
      );

      expect(
        () => assertApprovePermission(rbac, Permission.manageFinance),
        throwsA(isA<ApiFailureException>()),
      );
    });

    test('assertApproveAdmissions passes for principal', () {
      final rbac = RbacService(
        UserPermissions.forRole(ErpRole.principal),
      );

      expect(
        () => assertApproveAdmissions(rbac),
        returnsNormally,
      );
    });
  });
}
