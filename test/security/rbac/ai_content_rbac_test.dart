import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI content RBAC', () {
    test('ai content route maps to runAiCopilot', () {
      expect(
        erpRoutePermissionFor(RouteNames.aiContent),
        Permission.runAiCopilot,
      );
    });

    test('roles with runAiCopilot can access ai content route', () {
      for (final role in [
        ErpRole.superAdmin,
        ErpRole.schoolAdmin,
        ErpRole.principal,
        ErpRole.financeAdmin,
        ErpRole.admissionsCounselor,
      ]) {
        final rbac = RbacService(UserPermissions.forRole(role));
        expect(canAccessErpRoute(rbac, RouteNames.aiContent), isTrue);
      }
    });
  });
}
