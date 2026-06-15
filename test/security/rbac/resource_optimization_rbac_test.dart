import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Resource optimization RBAC', () {
    test('route allows either operations view or management manage permissions',
        () {
      final managementRbac =
          RbacService(UserPermissions.forRole(ErpRole.management));
      expect(
        canAccessErpRoute(managementRbac, RouteNames.resourceOptimization),
        isTrue,
      );

      final principalRbac =
          RbacService(UserPermissions.forRole(ErpRole.principal));
      expect(
        canAccessErpRoute(principalRbac, RouteNames.resourceOptimization),
        isTrue,
      );
    });

    test('route denies role without both permissions', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.teacher));
      expect(canAccessErpRoute(rbac, RouteNames.resourceOptimization), isFalse);
    });
  });
}
