import 'package:akshara_erp/core/config/chain_scope.dart';
import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/school_config/school_configuration_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/admin/admin_navigation_provider.dart';
import 'package:akshara_erp/features/admin/models/admin_nav_models.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final defaultCapabilities = SchoolConfiguration.demoDefault().capabilities;

  group('adminNavDestinationsProvider', () {
    test('superAdmin sees all school-build ERP module groups', () {
      // School build (SchoolBuildScope): non-school verticals (healthcare,
      // salon, restaurant, accommodation, industry), white-label and the
      // experimental extras (org builder, platform ops, dynamic widgets) are
      // hidden. Multi-school management (control center, director) is kept.
      final container = ProviderContainer(
        overrides: [
          schoolCapabilitiesProvider.overrideWithValue(defaultCapabilities),
          isChainOrgProvider.overrideWithValue(false),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final destinations = container.read(adminNavDestinationsProvider);
      expect(destinations, hasLength(15));
      expect(
        destinations.map((d) => d.route).toList(),
        [
          RouteNames.admin,
          RouteNames.admissionsDashboard,
          RouteNames.growthPlatform, // Marketing engine (B6)
          RouteNames.financeDashboard,
          RouteNames.sisDashboard,
          RouteNames.hrDashboard,
          RouteNames.employees, // Employee Platform (Journey Wave 4 — MJ-H23)
          RouteNames.managementDashboard,
          RouteNames.transportDashboard,
          RouteNames.hostelDashboard,
          RouteNames.libraryDashboard,
          RouteNames.inventoryDashboard,
          RouteNames.alumniDashboard,
          RouteNames.controlCenterDashboard,
          RouteNames.directorDashboard,
        ],
      );

      // Hidden modules are absent from the school build.
      final routes = destinations.map((d) => d.route).toSet();
      expect(routes, isNot(contains(RouteNames.salon)));
      expect(routes, isNot(contains(RouteNames.healthcare)));
      expect(routes, isNot(contains(RouteNames.whiteLabel)));
      expect(routes, isNot(contains(RouteNames.organizationBuilder)));
      expect(routes, isNot(contains(RouteNames.dynamicWidgets)));
    });

    test('financeAdmin sees finance and admin hub only', () {
      final container = ProviderContainer(
        overrides: [
          schoolCapabilitiesProvider.overrideWithValue(defaultCapabilities),
          isChainOrgProvider.overrideWithValue(false),
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
          schoolCapabilitiesProvider.overrideWithValue(defaultCapabilities),
          isChainOrgProvider.overrideWithValue(false),
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
          schoolCapabilitiesProvider.overrideWithValue(defaultCapabilities),
          isChainOrgProvider.overrideWithValue(false),
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

    test('chain org surfaces the organization-builder module (M3 gate)', () {
      final container = ProviderContainer(
        overrides: [
          schoolCapabilitiesProvider.overrideWithValue(defaultCapabilities),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
          isChainOrgProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      final routes =
          container.read(adminNavDestinationsProvider).map((d) => d.route);
      expect(routes, contains(RouteNames.organizationBuilder));
    });

    test('independent school hides the organization-builder module (M3 gate)',
        () {
      final container = ProviderContainer(
        overrides: [
          schoolCapabilitiesProvider.overrideWithValue(defaultCapabilities),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
          isChainOrgProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      final routes =
          container.read(adminNavDestinationsProvider).map((d) => d.route);
      expect(routes, isNot(contains(RouteNames.organizationBuilder)));
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
