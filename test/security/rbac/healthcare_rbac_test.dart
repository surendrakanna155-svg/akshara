import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('healthcare RBAC', () {
    test('route maps to viewHealthcare', () {
      expect(
        erpRoutePermissionFor(RouteNames.healthcare),
        Permission.viewHealthcare,
      );
    });

    test('super admin and school admin can access', () {
      for (final role in [ErpRole.superAdmin, ErpRole.schoolAdmin]) {
        final rbac = RbacService(UserPermissions.forRole(role));
        expect(canAccessErpRoute(rbac, RouteNames.healthcare), isTrue);
      }
    });

    test('finance admin cannot access', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.financeAdmin));
      expect(canAccessErpRoute(rbac, RouteNames.healthcare), isFalse);
    });
  });
}
