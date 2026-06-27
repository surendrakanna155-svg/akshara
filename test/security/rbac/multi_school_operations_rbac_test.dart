import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multi-school operations RBAC', () {
    test('routes map to viewMultiSchoolOperations permission', () {
      expect(
        erpRoutePermissionFor(RouteNames.multiSchoolPortfolio),
        Permission.viewMultiSchoolOperations,
      );
      expect(
        erpRoutePermissionFor(RouteNames.multiSchoolOnboarding),
        Permission.viewMultiSchoolOperations,
      );
    });

    test('school admin and management can access routes', () {
      for (final role in [
        ErpRole.schoolAdmin,
        ErpRole.management,
      ]) {
        final rbac = RbacService(UserPermissions.forRole(role));
        expect(
            canAccessErpRoute(rbac, RouteNames.multiSchoolPortfolio), isTrue);
      }
    });

    test('super admin cannot access (SA-1: unseeded server-side)', () {
      // Multi-school operations have no server migration seed, so the client
      // matrix must not advertise them to superAdmin.
      final rbac = RbacService(UserPermissions.forRole(ErpRole.superAdmin));
      expect(canAccessErpRoute(rbac, RouteNames.multiSchoolPortfolio), isFalse);
    });
  });
}
