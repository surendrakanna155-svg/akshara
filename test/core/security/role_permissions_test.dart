import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/role_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RolePermissionMatrix', () {
    test('superAdmin has control center permissions', () {
      final permissions =
          RolePermissionMatrix.permissionsFor(ErpRole.superAdmin);
      expect(permissions.contains(Permission.viewControlCenter), isTrue);
      expect(permissions.contains(Permission.manageControlCenter), isTrue);
    });

    test('schoolAdmin lacks control center permissions', () {
      final permissions =
          RolePermissionMatrix.permissionsFor(ErpRole.schoolAdmin);
      expect(permissions.contains(Permission.viewControlCenter), isFalse);
      expect(permissions.contains(Permission.viewFinance), isTrue);
    });

    test('financeAdmin is finance-scoped', () {
      final permissions =
          RolePermissionMatrix.permissionsFor(ErpRole.financeAdmin);
      expect(permissions.contains(Permission.viewFinance), isTrue);
      expect(permissions.contains(Permission.manageFinance), isTrue);
      expect(permissions.contains(Permission.approveRefunds), isTrue);
      expect(permissions.contains(Permission.viewAdmissions), isFalse);
    });

    test('admissionsCounselor can view admissions and SIS', () {
      final permissions =
          RolePermissionMatrix.permissionsFor(ErpRole.admissionsCounselor);
      expect(permissions.contains(Permission.viewAdmissions), isTrue);
      expect(permissions.contains(Permission.manageAdmissions), isTrue);
      expect(permissions.contains(Permission.viewSis), isTrue);
      expect(permissions.contains(Permission.viewFinance), isFalse);
    });

    test('principal has cross-module view access', () {
      final permissions = RolePermissionMatrix.permissionsFor(ErpRole.principal);
      expect(permissions.contains(Permission.viewAdmissions), isTrue);
      expect(permissions.contains(Permission.viewFinance), isTrue);
      expect(permissions.contains(Permission.viewSis), isTrue);
      expect(permissions.contains(Permission.viewManagement), isTrue);
      expect(permissions.contains(Permission.viewControlCenter), isFalse);
    });

    test('parent has parent experience permission; student has none', () {
      expect(
        RolePermissionMatrix.permissionsFor(ErpRole.parent).contains(
          Permission.viewParentExperience,
        ),
        isTrue,
      );
      expect(
        RolePermissionMatrix.permissionsFor(ErpRole.student).values,
        isEmpty,
      );
    });
  });
}
