import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('White label RBAC', () {
    test('route maps to viewWhiteLabelPlatform', () {
      expect(
        erpRoutePermissionFor(RouteNames.whiteLabel),
        Permission.viewWhiteLabelPlatform,
      );
    });

    test('super admin cannot access (SA-1: unseeded server-side)', () {
      // White-label platform has no server migration seed, so the client
      // matrix must not advertise it to superAdmin.
      final rbac = RbacService(UserPermissions.forRole(ErpRole.superAdmin));
      expect(canAccessErpRoute(rbac, RouteNames.whiteLabel), isFalse);
    });
  });
}
