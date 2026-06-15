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

    test('super admin can access branch route', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.superAdmin));
      expect(canAccessErpRoute(rbac, RouteNames.branches), isTrue);
    });
  });
}
