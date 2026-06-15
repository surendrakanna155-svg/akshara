import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Franchise RBAC', () {
    test('franchise route maps to viewFranchiseOperations', () {
      expect(
        erpRoutePermissionFor(RouteNames.franchise),
        Permission.viewFranchiseOperations,
      );
    });

    test('management can access franchise route', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.management));
      expect(canAccessErpRoute(rbac, RouteNames.franchise), isTrue);
    });
  });
}
