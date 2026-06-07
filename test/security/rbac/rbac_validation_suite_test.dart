import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_module_registry.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RBAC validation suite', () {
    test('every ERP module has a view permission mapping', () {
      expect(RbacModuleRegistry.modules, isNotEmpty);
      for (final module in RbacModuleRegistry.modules) {
        expect(module.view, isA<Permission>());
      }
    });

    test('finance admin can manage finance but not approve refunds without grant', () {
      final rbac = RbacService(
        UserPermissions(
          role: ErpRole.financeAdmin,
          permissionSet: PermissionSet.from(const [
            Permission.viewFinance,
            Permission.manageFinance,
          ]),
        ),
      );

      expect(rbac.hasManagePermission(Permission.manageFinance), isTrue);
      expect(rbac.hasApprovePermission(Permission.approveRefunds), isFalse);
    });

    test('principal can approve admissions', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.principal));
      expect(rbac.hasApprovePermission(Permission.approveAdmissions), isTrue);
    });

    test('teacher cannot manage admissions', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.teacher));
      expect(rbac.hasManagePermission(Permission.manageAdmissions), isFalse);
    });
  });
}
