import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer containerFor(ErpRole role) {
    final container = ProviderContainer(
      overrides: [
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRole(role),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('module view providers', () {
    test('transportManager sees transport only among fleet modules', () {
      final c = containerFor(ErpRole.transportManager);
      expect(c.read(canViewTransportProvider), isTrue);
      expect(c.read(canViewHostelProvider), isFalse);
      expect(c.read(canViewFinanceProvider), isFalse);
    });

    test('hostelManager sees hostel module', () {
      final c = containerFor(ErpRole.hostelManager);
      expect(c.read(canViewHostelProvider), isTrue);
      expect(c.read(canViewTransportProvider), isFalse);
    });

    test('librarian sees library module', () {
      final c = containerFor(ErpRole.librarian);
      expect(c.read(canViewLibraryProvider), isTrue);
      expect(c.read(canViewInventoryProvider), isFalse);
    });

    test('inventoryManager sees inventory module', () {
      final c = containerFor(ErpRole.inventoryManager);
      expect(c.read(canViewInventoryProvider), isTrue);
      expect(c.read(canViewLibraryProvider), isFalse);
    });

    test('management sees executive modules read-only subset', () {
      final c = containerFor(ErpRole.management);
      expect(c.read(canViewManagementProvider), isTrue);
      expect(c.read(canManageFinanceProvider), isTrue);
      expect(c.read(canManageAdmissionsProvider), isFalse);
      expect(c.read(canViewControlCenterProvider), isFalse);
    });

    test('schoolAdmin has school-wide access without control center', () {
      final c = containerFor(ErpRole.schoolAdmin);
      expect(c.read(canViewFinanceProvider), isTrue);
      expect(c.read(canViewHrProvider), isTrue);
      expect(c.read(canViewControlCenterProvider), isFalse);
    });
  });

  group('currentPermissionsProvider', () {
    test('exposes finance permissions for financeAdmin', () {
      final c = containerFor(ErpRole.financeAdmin);
      final permissions = c.read(currentPermissionsProvider);
      expect(permissions.contains(Permission.viewFinance), isTrue);
      expect(permissions.contains(Permission.manageFinance), isTrue);
      expect(permissions.contains(Permission.viewAdmissions), isFalse);
    });
  });
}
