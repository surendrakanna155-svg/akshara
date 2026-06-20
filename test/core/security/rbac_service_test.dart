import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_test_overrides.dart';

void main() {
  group('RbacService', () {
    test('hasPermission checks single grant', () {
      final service = RbacService(
        UserPermissions.forRole(ErpRole.financeAdmin),
      );
      expect(service.hasPermission(Permission.viewFinance), isTrue);
      expect(service.hasPermission(Permission.viewAdmissions), isFalse);
    });

    test('multi-role unions permissions across all held roles', () {
      // Surendra: Teacher + Inventory Manager → both permission sets.
      final service = RbacService(
        UserPermissions.forRoles([ErpRole.teacher, ErpRole.inventoryManager]),
      );
      // From the teacher hat:
      expect(service.hasPermission(Permission.markAttendance), isTrue);
      expect(service.hasPermission(Permission.manageExamMarks), isTrue);
      // From the inventory-manager hat:
      expect(service.hasPermission(Permission.manageInventory), isTrue);
      expect(service.hasPermission(Permission.createInventoryPo), isTrue);
      // Neither hat grants control center:
      expect(service.hasPermission(Permission.viewControlCenter), isFalse);
      // Holds both roles; primary is the first.
      expect(service.hasRole(ErpRole.teacher), isTrue);
      expect(service.hasRole(ErpRole.inventoryManager), isTrue);
      expect(service.role, ErpRole.teacher);
      expect(service.roles.length, 2);
    });

    test('single role does NOT leak the other hat\'s permissions', () {
      final teacherOnly = RbacService(UserPermissions.forRole(ErpRole.teacher));
      expect(teacherOnly.hasPermission(Permission.manageInventory), isFalse);
      final inventoryOnly =
          RbacService(UserPermissions.forRole(ErpRole.inventoryManager));
      expect(inventoryOnly.hasPermission(Permission.markAttendance), isFalse);
    });

    test('hasAnyPermission and hasAllPermissions', () {
      final service = RbacService(
        UserPermissions.forRole(ErpRole.principal),
      );
      expect(
        service.hasAnyPermission([
          Permission.viewControlCenter,
          Permission.viewFinance,
        ]),
        isTrue,
      );
      expect(
        service.hasAllPermissions([
          Permission.viewAdmissions,
          Permission.approveAdmissions,
        ]),
        isTrue,
      );
      expect(
        service.hasAllPermissions([
          Permission.viewAdmissions,
          Permission.manageFinance,
        ]),
        isFalse,
      );
    });
  });

  group('Riverpod RBAC providers', () {
    test('staff session resolves superAdmin permissions by default', () {
      final container = ProviderContainer(
        overrides: [
          authStateOverride(
            AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '9876543210',
              displayName: 'Staff',
              role: UserRole.staff,
              claims: AuthClaims.demoForRole(erpRole: ErpRole.superAdmin),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(canViewControlCenterProvider), isTrue);
      expect(container.read(canManageAdmissionsProvider), isTrue);
    });

    test('financeAdmin cannot view control center', () {
      final container = ProviderContainer(
        overrides: [
          authStateOverride(
            AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '9876543210',
              displayName: 'Finance',
              role: UserRole.staff,
              claims: AuthClaims.demoForRole(erpRole: ErpRole.financeAdmin),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(canViewFinanceProvider), isTrue);
      expect(container.read(canViewControlCenterProvider), isFalse);
      expect(container.read(canManageAdmissionsProvider), isFalse);
    });

    test('multi-role claims resolve a unioned permission set', () {
      final container = ProviderContainer(
        overrides: [
          authStateOverride(
            AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '9000000099',
              displayName: 'Surendra',
              role: UserRole.staff,
              claims: AuthClaims.demoForRole(
                erpRoles: [ErpRole.teacher, ErpRole.inventoryManager],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final rbac = container.read(rbacServiceProvider);
      // Teacher hat + Inventory hat both resolve through the provider:
      expect(rbac.hasPermission(Permission.markAttendance), isTrue);
      expect(container.read(canViewInventoryProvider), isTrue);
      expect(rbac.roles.length, 2);
      expect(container.read(canViewControlCenterProvider), isFalse);
    });
  });
}
