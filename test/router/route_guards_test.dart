import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('erpRoutePermissionFor', () {
    test('maps module prefixes to view permissions', () {
      expect(
        erpRoutePermissionFor(RouteNames.financeDashboard),
        Permission.viewFinance,
      );
      expect(
        erpRoutePermissionFor(RouteNames.financeCollections),
        Permission.viewFinance,
      );
      expect(
        erpRoutePermissionFor(RouteNames.controlCenterSchools),
        Permission.viewControlCenter,
      );
      expect(
        erpRoutePermissionFor(RouteNames.directorDashboard),
        Permission.viewDirectorPortal,
      );
      expect(
        erpRoutePermissionFor(RouteNames.copilot),
        Permission.viewAiCopilot,
      );
      expect(erpRoutePermissionFor(RouteNames.parentDashboard), isNull);
    });
  });

  group('canAccessErpRoute', () {
    final superAdmin = RbacService(UserPermissions.forRole(ErpRole.superAdmin));
    final financeAdmin =
        RbacService(UserPermissions.forRole(ErpRole.financeAdmin));
    final counselor =
        RbacService(UserPermissions.forRole(ErpRole.admissionsCounselor));

    test('superAdmin can access all ERP modules', () {
      expect(canAccessErpRoute(superAdmin, RouteNames.admin), isTrue);
      expect(
        canAccessErpRoute(superAdmin, RouteNames.controlCenterDashboard),
        isTrue,
      );
      expect(
        canAccessErpRoute(superAdmin, RouteNames.admissionsLeads),
        isTrue,
      );
    });

    test('financeAdmin blocked from admissions and control center', () {
      expect(
        canAccessErpRoute(financeAdmin, RouteNames.financeDashboard),
        isTrue,
      );
      expect(
        canAccessErpRoute(financeAdmin, RouteNames.admissionsDashboard),
        isFalse,
      );
      expect(
        canAccessErpRoute(financeAdmin, RouteNames.controlCenterDashboard),
        isFalse,
      );
      expect(
        canAccessErpRoute(financeAdmin, RouteNames.directorDashboard),
        isFalse,
      );
    });

    test('admissionsCounselor can access admissions but not finance', () {
      expect(
        canAccessErpRoute(counselor, RouteNames.admissionsDashboard),
        isTrue,
      );
      expect(
        canAccessErpRoute(counselor, RouteNames.sisDashboard),
        isTrue,
      );
      expect(
        canAccessErpRoute(counselor, RouteNames.financeDashboard),
        isFalse,
      );
    });
  });
}
