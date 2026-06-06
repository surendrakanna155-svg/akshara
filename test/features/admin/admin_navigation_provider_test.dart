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
          adminPersonaProvider.overrideWithValue(AdminPersona.superAdmin),
        ],
      );
      addTearDown(container.dispose);

      final destinations = container.read(adminNavDestinationsProvider);
      expect(destinations, hasLength(8));
      expect(
        destinations.map((d) => d.route).toList(),
        [
          RouteNames.admin,
          RouteNames.admissionsDashboard,
          RouteNames.financeDashboard,
          RouteNames.sisDashboard,
          RouteNames.hr,
          RouteNames.management,
          RouteNames.transport,
          RouteNames.hostel,
        ],
      );
    });

    test('financeAdmin sees finance and admin hub only', () {
      final container = ProviderContainer(
        overrides: [
          adminPersonaProvider.overrideWithValue(AdminPersona.financeAdmin),
        ],
      );
      addTearDown(container.dispose);

      final routes =
          container.read(adminNavDestinationsProvider).map((d) => d.route);
      expect(routes, contains(RouteNames.admin));
      expect(routes, contains(RouteNames.financeDashboard));
      expect(routes, isNot(contains(RouteNames.admissionsDashboard)));
      expect(routes, isNot(contains(RouteNames.hr)));
    });

    test('counselor sees admissions modules', () {
      final container = ProviderContainer(
        overrides: [
          adminPersonaProvider.overrideWithValue(AdminPersona.counselor),
        ],
      );
      addTearDown(container.dispose);

      final routes =
          container.read(adminNavDestinationsProvider).map((d) => d.route);
      expect(routes, contains(RouteNames.admissionsDashboard));
      expect(routes, contains(RouteNames.sisDashboard));
      expect(routes, isNot(contains(RouteNames.financeDashboard)));
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
