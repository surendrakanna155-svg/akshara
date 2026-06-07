import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final roles = ErpRole.staffErpRoles;

  group('ERP route protection inventory', () {
    for (final role in roles) {
      test('$role finance route access matches matrix', () {
        final rbac = RbacService(UserPermissions.forRole(role));
        final allowed = canAccessErpRoute(rbac, RouteNames.financeDashboard);
        final expected = UserPermissions.forRole(role)
            .has(Permission.viewFinance);
        expect(allowed, expected);
      });
    }

    for (final role in roles) {
      test('$role control center access is superAdmin only', () {
        final rbac = RbacService(UserPermissions.forRole(role));
        final allowed =
            canAccessErpRoute(rbac, RouteNames.controlCenterDashboard);
        expect(allowed, role == ErpRole.superAdmin);
      });
    }

    test('all ERP prefixes map to a permission', () {
      for (final prefix in RouteNames.adminErpRoutes) {
        expect(erpRoutePermissionFor(prefix), isNotNull);
        expect(erpRoutePermissionFor('$prefix/dashboard'), isNotNull);
      }
    });
  });
}
