import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/server_rbac_route_inventory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Server RBAC validation suite', () {
    test('permission slugs align with Permission enum', () {
      final enumNames = Permission.values.map((p) => p.name).toSet();
      for (final slug in ServerRbacRouteInventory.permissionSlugs) {
        expect(
          enumNames.contains(slug),
          isTrue,
          reason: 'Permission enum missing $slug',
        );
      }
    });

    test('all ERP modules represented in server inventory', () {
      expect(ServerRbacRouteInventory.modules, isNotEmpty);
      expect(ServerRbacRouteInventory.modules, contains('admissions'));
      expect(ServerRbacRouteInventory.modules, contains('finance'));
      expect(ServerRbacRouteInventory.modules, contains('audit'));
      expect(ServerRbacRouteInventory.modules, contains('copilot'));
      expect(ServerRbacRouteInventory.modules, contains('parent'));
    });

    test('protected route count meets Sprint 6 minimum', () {
      expect(
        ServerRbacRouteInventory.protectedRouteCount,
        greaterThanOrEqualTo(20),
      );
    });

    test('approve permissions require separate grants from manage', () {
      expect(Permission.approveAdmissions, isNot(Permission.manageAdmissions));
      expect(Permission.approveRefunds, isNot(Permission.manageFinance));
    });
  });
}
