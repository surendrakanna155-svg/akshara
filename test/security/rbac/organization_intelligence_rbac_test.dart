import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Organization intelligence RBAC', () {
    test('route maps to viewOrganizationIntelligence', () {
      expect(
        erpRoutePermissionFor(RouteNames.organizationIntelligence),
        Permission.viewOrganizationIntelligence,
      );
    });

    test('principal can access organization intelligence route', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.principal));
      expect(
          canAccessErpRoute(rbac, RouteNames.organizationIntelligence), isTrue);
    });
  });
}
