import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/features/admin/global_search/global_search_registry.dart';
import 'package:akshara_erp/router/route_guards.dart';
import 'package:akshara_erp/router/route_names.dart';

void main() {
  test('global search finds finance destinations', () {
    final results = GlobalSearchRegistry.search('defaulter');
    expect(results.any((e) => e.route == RouteNames.financeDefaulters), isTrue);
  });

  test('global search matches module keywords', () {
    final results = GlobalSearchRegistry.search('enrollment');
    expect(results.any((e) => e.route == RouteNames.admissionsEnrollment), isTrue);
  });

  group('RBAC filtering (MJ-L8 / ADMIN-6)', () {
    // A predicate granting only the named permissions.
    bool Function(Permission) granting(Set<Permission> held) =>
        held.contains;

    test('user lacking finance permission does NOT see finance entries', () {
      final results = GlobalSearchRegistry.search(
        'finance',
        hasPermission: granting(const {Permission.viewSis}),
      );
      expect(
        results.any((e) => e.route == RouteNames.financeDefaulters),
        isFalse,
      );
      expect(
        results.any((e) => e.route == RouteNames.financeDashboard),
        isFalse,
      );
    });

    test('user WITH finance permission sees finance entries', () {
      final results = GlobalSearchRegistry.search(
        'finance',
        hasPermission: granting(const {Permission.viewFinance}),
      );
      expect(
        results.any((e) => e.route == RouteNames.financeDashboard),
        isTrue,
      );
    });

    test('finance permission alone does not expose the executive dashboard',
        () {
      // financeExecutiveDashboard is gated by its own, stronger permission.
      final results = GlobalSearchRegistry.search(
        'executive',
        hasPermission: granting(const {Permission.viewFinance}),
      );
      expect(
        results.any((e) => e.route == RouteNames.financeExecutiveDashboard),
        isFalse,
      );

      final privileged = GlobalSearchRegistry.search(
        'executive',
        hasPermission: granting(const {
          Permission.viewFinanceExecutiveDashboard,
        }),
      );
      expect(
        privileged.any((e) => e.route == RouteNames.financeExecutiveDashboard),
        isTrue,
      );
    });

    test('generic role-dashboard entries stay visible to everyone', () {
      // Parent/teacher/student dashboards carry no requiredPermission.
      final results = GlobalSearchRegistry.search(
        '',
        hasPermission: granting(const {}),
      );
      expect(
        results.any((e) => e.route == RouteNames.parentDashboard),
        isTrue,
      );
      expect(
        results.any((e) => e.route == RouteNames.teacherDashboard),
        isTrue,
      );
    });

    test('every entry permission matches its route guard', () {
      // Each entry that carries a requiredPermission must use the SAME view
      // permission the route guard enforces — no drift between the two maps.
      for (final entry in GlobalSearchRegistry.entries) {
        final permission = entry.requiredPermission;
        if (permission == null) continue;
        expect(
          permission,
          erpRoutePermissionFor(entry.route),
          reason: 'search entry "${entry.label}" (${entry.route}) must match '
              'its route guard permission',
        );
      }
    });
  });
}
