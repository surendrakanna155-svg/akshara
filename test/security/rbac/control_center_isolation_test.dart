import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_module_registry.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Control Center SuperAdmin isolation', () {
    test('super admin with view permission can access control center', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.superAdmin));
      expect(
        RbacModuleRegistry.canAccessControlCenter(
          role: rbac.role,
          hasViewPermission: rbac.hasPermission(Permission.viewControlCenter),
        ),
        isTrue,
      );
    });

    test('finance admin cannot access control center even with stray view flag', () {
      final rbac = RbacService(
        UserPermissions(
          role: ErpRole.financeAdmin,
          permissionSet: PermissionSet.from(const [
            Permission.viewControlCenter,
          ]),
        ),
      );

      expect(
        RbacModuleRegistry.canAccessControlCenter(
          role: rbac.role,
          hasViewPermission: rbac.hasPermission(Permission.viewControlCenter),
        ),
        isFalse,
      );
    });

    test('super admin role is required for control center', () {
      for (final role in ErpRole.staffErpRoles) {
        if (role == ErpRole.superAdmin) continue;
        final rbac = RbacService(
          UserPermissions(
            role: role,
            permissionSet: PermissionSet.all(),
          ),
        );
        expect(
          RbacModuleRegistry.canAccessControlCenter(
            role: rbac.role,
            hasViewPermission: true,
          ),
          isFalse,
          reason: role.name,
        );
      }
    });
  });
}
