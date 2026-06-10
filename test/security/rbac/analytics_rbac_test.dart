import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Analytics intelligence RBAC', () {
    test('intelligence route maps to viewAnalytics', () {
      expect(
        erpRoutePermissionFor(RouteNames.managementIntelligence),
        Permission.viewAnalytics,
      );
    });

    test('principal role can access intelligence route', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.principal));
      expect(canAccessErpRoute(rbac, RouteNames.managementIntelligence), isTrue);
    });

    test('finance admin cannot access intelligence route', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.financeAdmin));
      expect(canAccessErpRoute(rbac, RouteNames.managementIntelligence), isFalse);
    });

    test('viewSchoolHealth is granted to management role', () {
      final permissions = UserPermissions.forRole(ErpRole.management);
      expect(permissions.has(Permission.viewSchoolHealth), isTrue);
    });
  });
}
