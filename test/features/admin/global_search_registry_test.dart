import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
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

    // P1-7 (2026-07-28) — replaces 'generic role-dashboard entries stay visible
    // to everyone'. The Parent/Teacher/Student Dashboard entries were the only
    // ones with no requiredPermission, so isVisibleTo() showed them to every
    // staff user of this sheet — but the sheet only renders inside the admin
    // ERP shell, and the persona shells are closed to staff by ROLE (not by
    // permission). Tapping bounced the user to /admin AND wrote the dead route
    // into Recents, so it resurfaced at the top of the sheet forever. They were
    // removed: no permission can express "holds ErpRole.teacher", and a tile
    // that silently bounces is worse than no tile.
    test('no search entry is an unreachable persona-shell destination', () {
      final everything = GlobalSearchRegistry.search(
        '',
        hasPermission: granting(const {}),
      );
      for (final route in const [
        RouteNames.parentDashboard,
        RouteNames.teacherDashboard,
        RouteNames.studentDashboard,
      ]) {
        expect(
          everything.any((e) => e.route == route),
          isFalse,
          reason: '$route cannot be entered from the admin shell — offering it '
              'in global search is a guaranteed dead link',
        );
      }
    });

    test('every search entry declares the permission that guards it', () {
      // With the persona dashboards gone, EVERY remaining entry must carry a
      // requiredPermission — otherwise it is visible to staff who cannot open
      // it. (The stronger parity assertion lives in the test below.)
      for (final entry in GlobalSearchRegistry.entries) {
        expect(
          entry.requiredPermission,
          isNotNull,
          reason: 'search entry "${entry.label}" (${entry.route}) has no '
              'requiredPermission, so it is offered to every staff user',
        );
      }
    });

    test('disabling a module hides its entries from search (gap G6)', () {
      // School has inventory turned off — its entries must not surface even with
      // the matching view-permission, so tapping never hits AccessDeniedScreen.
      final disabledInventory = GlobalSearchRegistry.search(
        'inventory',
        hasPermission: granting(const {
          Permission.viewInventory,
          Permission.viewInventoryIntelligence,
        }),
        capabilities: const SchoolCapabilities(inventory: false),
      );
      expect(
        disabledInventory.any((e) => e.route == RouteNames.inventoryDashboard),
        isFalse,
      );

      // With the module enabled the same query returns the entries.
      final enabledInventory = GlobalSearchRegistry.search(
        'inventory',
        hasPermission: granting(const {Permission.viewInventory}),
        capabilities: const SchoolCapabilities(),
      );
      expect(
        enabledInventory.any((e) => e.route == RouteNames.inventoryDashboard),
        isTrue,
      );

      // Core entries (no capabilityModule) stay visible regardless of config.
      final core = GlobalSearchRegistry.search(
        'finance',
        hasPermission: granting(const {Permission.viewFinance}),
        capabilities: const SchoolCapabilities(inventory: false),
      );
      expect(
        core.any((e) => e.route == RouteNames.financeDashboard),
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
