import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('salon RBAC', () {
    test('route maps to viewSalonBusiness', () {
      expect(
        erpRoutePermissionFor(RouteNames.salon),
        Permission.viewSalonBusiness,
      );
    });

    test('super admin can access; school roles cannot (least privilege)', () {
      expect(
        canAccessErpRoute(
            RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
            RouteNames.salon),
        isTrue,
      );
      for (final role in [ErpRole.schoolAdmin, ErpRole.management]) {
        final rbac = RbacService(UserPermissions.forRole(role));
        expect(canAccessErpRoute(rbac, RouteNames.salon), isFalse);
      }
    });

    test('finance admin cannot access', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.financeAdmin));
      expect(canAccessErpRoute(rbac, RouteNames.salon), isFalse);
    });
  });
}
