import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Director portal RBAC', () {
    test('director route maps to viewDirectorPortal permission', () {
      expect(
        erpRoutePermissionFor(RouteNames.directorDashboard),
        Permission.viewDirectorPortal,
      );
    });

    test('superAdmin schoolAdmin and management can access director routes',
        () {
      for (final role in [
        ErpRole.superAdmin,
        ErpRole.schoolAdmin,
        ErpRole.management,
      ]) {
        final rbac = RbacService(UserPermissions.forRole(role));
        expect(canAccessErpRoute(rbac, RouteNames.directorReports), isTrue);
      }
    });

    test('teacher cannot access director routes', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.teacher));
      expect(canAccessErpRoute(rbac, RouteNames.directorDashboard), isFalse);
    });
  });
}
