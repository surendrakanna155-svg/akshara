import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Copilot RBAC', () {
    test('copilot route maps to viewAiCopilot', () {
      expect(
        erpRoutePermissionFor(RouteNames.copilot),
        Permission.viewAiCopilot,
      );
    });

    test('staff roles with copilot access can open route', () {
      for (final role in [
        ErpRole.superAdmin,
        ErpRole.schoolAdmin,
        ErpRole.principal,
        ErpRole.financeAdmin,
        ErpRole.admissionsCounselor,
      ]) {
        final rbac = RbacService(UserPermissions.forRole(role));
        expect(
          canAccessErpRoute(rbac, RouteNames.copilot),
          isTrue,
          reason: '$role should access copilot',
        );
        expect(
          rbac.hasPermission(Permission.runAiCopilot),
          isTrue,
          reason: '$role should run copilot queries',
        );
      }
    });

    test('teacher role cannot access copilot route', () {
      final rbac = RbacService(UserPermissions.forRole(ErpRole.teacher));
      expect(canAccessErpRoute(rbac, RouteNames.copilot), isFalse);
      expect(rbac.hasPermission(Permission.viewAiCopilot), isFalse);
      expect(rbac.hasPermission(Permission.runAiCopilot), isFalse);
    });
  });
}
