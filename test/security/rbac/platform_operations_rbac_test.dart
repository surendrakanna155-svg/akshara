import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Platform operations RBAC', () {
    test('routes map to viewPlatformOperations permission', () {
      for (final route in [
        RouteNames.platformOperations,
        RouteNames.platformOperationsAlerts,
        RouteNames.platformOperationsSecurity,
        RouteNames.platformOperationsTenantIsolation,
        RouteNames.platformOperationsReadiness,
      ]) {
        expect(
          erpRoutePermissionFor(route),
          Permission.viewPlatformOperations,
        );
      }
    });

    test('super admin school admin and management can access routes', () {
      for (final role in [
        ErpRole.superAdmin,
        ErpRole.schoolAdmin,
        ErpRole.management,
      ]) {
        final rbac = RbacService(UserPermissions.forRole(role));
        expect(
          canAccessErpRoute(rbac, RouteNames.platformOperations),
          isTrue,
        );
      }
    });

    test('finance admin cannot access platform operations', () {
      final rbac =
          RbacService(UserPermissions.forRole(ErpRole.financeAdmin));
      expect(
        canAccessErpRoute(rbac, RouteNames.platformOperations),
        isFalse,
      );
    });
  });
}
