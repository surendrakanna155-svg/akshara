import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/admin/admin_navigation_provider.dart';
import 'package:akshara_erp/features/admin/models/admin_nav_models.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('adminNavDestinationsProvider', () {
    test('superAdmin sees all ERP module groups', () {
      final container = ProviderContainer(
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final destinations = container.read(adminNavDestinationsProvider);
      expect(destinations, hasLength(22));
      expect(
        destinations.map((d) => d.route).toList(),
        [
          RouteNames.admin,
          RouteNames.admissionsDashboard,
          RouteNames.financeDashboard,
          RouteNames.sisDashboard,
          RouteNames.hrDashboard,
          RouteNames.managementDashboard,
          RouteNames.transportDashboard,
          RouteNames.hostelDashboard,
          RouteNames.libraryDashboard,
          RouteNames.inventoryDashboard,
          RouteNames.alumniDashboard,
          RouteNames.controlCenterDashboard,
          RouteNames.directorDashboard,
          RouteNames.organizationBuilder,
          RouteNames.platformOperations,
          RouteNames.industry,
          RouteNames.healthcare,
          RouteNames.salon,
          RouteNames.restaurant,
          RouteNames.accommodation,
          RouteNames.whiteLabel,
          RouteNames.dynamicWidgets,
        ],
      );
    });

    test('financeAdmin sees finance and admin hub only', () {
      final container = ProviderContainer(
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final routes =
          container.read(adminNavDestinationsProvider).map((d) => d.route);
      expect(routes, contains(RouteNames.admin));
      expect(routes, contains(RouteNames.financeDashboard));
      expect(routes, isNot(contains(RouteNames.admissionsDashboard)));
      expect(routes, isNot(contains(RouteNames.hr)));
      expect(routes, isNot(contains(RouteNames.controlCenterDashboard)));
    });

    test('admissionsCounselor sees admissions and SIS modules', () {
      final container = ProviderContainer(
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      final routes =
          container.read(adminNavDestinationsProvider).map((d) => d.route);
      expect(routes, contains(RouteNames.admissionsDashboard));
      expect(routes, contains(RouteNames.sisDashboard));
      expect(routes, isNot(contains(RouteNames.financeDashboard)));
      expect(routes, isNot(contains(RouteNames.controlCenterDashboard)));
    });

    test('principal sees admissions, finance, SIS, and management', () {
      final container = ProviderContainer(
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      final routes =
          container.read(adminNavDestinationsProvider).map((d) => d.route);
      expect(routes, contains(RouteNames.admissionsDashboard));
      expect(routes, contains(RouteNames.financeDashboard));
      expect(routes, contains(RouteNames.sisDashboard));
      expect(routes, contains(RouteNames.managementDashboard));
      expect(routes, isNot(contains(RouteNames.controlCenterDashboard)));
    });
  });

  group('adminBreadcrumbsForModule', () {
    test('admin hub has single breadcrumb', () {
      final crumbs = adminBreadcrumbsForModule(AdminModule.admin);
      expect(crumbs, hasLength(1));
      expect(crumbs.first.label, 'Admin Hub');
      expect(crumbs.first.route, isNull);
    });

    test('child modules include admin hub link', () {
      final crumbs = adminBreadcrumbsForModule(AdminModule.admissions);
      expect(crumbs, hasLength(2));
      expect(crumbs.first.label, 'Admin Hub');
      expect(crumbs.first.route, RouteNames.admin);
      expect(crumbs.last.label, 'Admissions');
    });
  });
}
