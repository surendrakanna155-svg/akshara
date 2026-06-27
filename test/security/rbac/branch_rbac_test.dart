import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Branch RBAC', () {
    test('branch route maps to viewBranchOperations', () {
      expect(
        erpRoutePermissionFor(RouteNames.branches),
        Permission.viewBranchOperations,
      );
    });

    test('super admin cannot access branch route (SA-1: unseeded server-side)',
        () {
      // Branch operations have no server migration seed, so the client matrix
      // must not advertise them to superAdmin — otherwise the offline
      // local-matrix fallback would surface a mock-backed tile.
      final rbac = RbacService(UserPermissions.forRole(ErpRole.superAdmin));
      expect(canAccessErpRoute(rbac, RouteNames.branches), isFalse);
    });
  });
}
