import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final roles = ErpRole.staffErpRoles;

  group('ERP route protection inventory', () {
    for (final role in roles) {
      test('$role finance route access matches matrix', () {
        final rbac = RbacService(UserPermissions.forRole(role));
        final allowed = canAccessErpRoute(rbac, RouteNames.financeDashboard);
        final expected =
            UserPermissions.forRole(role).has(Permission.viewFinance);
        expect(allowed, expected);
      });
    }

    for (final role in roles) {
      test('$role control center access is superAdmin only', () {
        final rbac = RbacService(UserPermissions.forRole(role));
        final allowed =
            canAccessErpRoute(rbac, RouteNames.controlCenterDashboard);
        expect(allowed, role == ErpRole.superAdmin);
      });
    }

    for (final role in roles) {
      test('$role director portal access matches permission matrix', () {
        final rbac = RbacService(UserPermissions.forRole(role));
        final allowed = canAccessErpRoute(rbac, RouteNames.directorDashboard);
        final expected =
            UserPermissions.forRole(role).has(Permission.viewDirectorPortal);
        expect(allowed, expected);
      });
    }

    for (final role in roles) {
      test('$role organization builder access matches permission matrix', () {
        final rbac = RbacService(UserPermissions.forRole(role));
        final allowed =
            canAccessErpRoute(rbac, RouteNames.organizationBuilder);
        final expected = UserPermissions.forRole(role)
            .has(Permission.viewOrganizationBuilder);
        expect(allowed, expected);
      });
    }

    for (final role in roles) {
      test('$role dynamic widgets access matches permission matrix', () {
        final rbac = RbacService(UserPermissions.forRole(role));
        final allowed = canAccessErpRoute(rbac, RouteNames.dynamicWidgets);
        final expected =
            UserPermissions.forRole(role).has(Permission.viewDynamicWidgets);
        expect(allowed, expected);
      });
    }

    for (final role in roles) {
      test('$role platform operations access matches permission matrix', () {
        final rbac = RbacService(UserPermissions.forRole(role));
        final allowed =
            canAccessErpRoute(rbac, RouteNames.platformOperations);
        final expected = UserPermissions.forRole(role)
            .has(Permission.viewPlatformOperations);
        expect(allowed, expected);
      });
    }

    for (final role in roles) {
      test('$role industry framework access matches permission matrix', () {
        final rbac = RbacService(UserPermissions.forRole(role));
        final allowed = canAccessErpRoute(rbac, RouteNames.industry);
        final expected = UserPermissions.forRole(role)
            .has(Permission.viewIndustryFramework);
        expect(allowed, expected);
      });
    }

    for (final role in roles) {
      test('$role healthcare access matches permission matrix', () {
        final rbac = RbacService(UserPermissions.forRole(role));
        final allowed = canAccessErpRoute(rbac, RouteNames.healthcare);
        final expected =
            UserPermissions.forRole(role).has(Permission.viewHealthcare);
        expect(allowed, expected);
      });
    }

    for (final role in roles) {
      test('$role white label access matches permission matrix', () {
        final rbac = RbacService(UserPermissions.forRole(role));
        final allowed = canAccessErpRoute(rbac, RouteNames.whiteLabel);
        final expected = UserPermissions.forRole(role)
            .has(Permission.viewWhiteLabelPlatform);
        expect(allowed, expected);
      });
    }

    test('all ERP prefixes map to a permission', () {
      for (final prefix in RouteNames.adminErpRoutes) {
        expect(erpRoutePermissionFor(prefix), isNotNull);
        expect(erpRoutePermissionFor('$prefix/dashboard'), isNotNull);
      }
    });

    // Regression: a specific child route nested under a broader parent must
    // resolve to its OWN (more specific) permission, not the parent's. The
    // earlier insertion-order first-match returned the weaker parent permission
    // (e.g. /finance/intelligence -> viewFinance), letting a role that only
    // holds the parent perm reach the child = privilege escalation.
    test('nested child routes resolve to their specific permission', () {
      final cases = <String, Permission>{
        RouteNames.financeIntelligence: Permission.viewFinanceIntelligence,
        RouteNames.financeExecutiveDashboard:
            Permission.viewFinanceExecutiveDashboard,
        RouteNames.inventoryCopilot: Permission.viewInventoryIntelligence,
        RouteNames.inventoryLifecycle: Permission.viewInventoryIntelligence,
        RouteNames.teacherEffectiveness: Permission.viewTeacherEffectiveness,
        RouteNames.inventoryDistribution:
            Permission.viewInventoryDistribution,
      };
      cases.forEach((route, expected) {
        expect(erpRoutePermissionFor(route), expected,
            reason: '$route must require $expected, not its parent permission');
      });
    });

    // A role that holds only the broad parent permission must NOT reach a
    // child route that requires a distinct, narrower permission.
    test('parent-only permission does not unlock specific child routes', () {
      for (final role in roles) {
        final perms = UserPermissions.forRole(role);
        final rbac = RbacService(perms);
        if (perms.has(Permission.viewFinance) &&
            !perms.has(Permission.viewFinanceIntelligence)) {
          expect(canAccessErpRoute(rbac, RouteNames.financeIntelligence), false,
              reason:
                  '$role holds viewFinance but not viewFinanceIntelligence');
        }
        if (perms.has(Permission.viewInventory) &&
            !perms.has(Permission.viewInventoryIntelligence)) {
          expect(canAccessErpRoute(rbac, RouteNames.inventoryCopilot), false,
              reason:
                  '$role holds viewInventory but not viewInventoryIntelligence');
        }
      }
    });
  });
}
