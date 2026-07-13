import 'package:akshara_erp/core/config/school_build_scope.dart';
import 'package:akshara_erp/features/admin/models/admin_nav_models.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SchoolBuildScope (hide non-school + experimental modules)', () {
    test('non-school verticals are hidden modules', () {
      for (final module in [
        AdminModule.healthcare,
        AdminModule.salon,
        AdminModule.restaurant,
        AdminModule.accommodation,
        AdminModule.industry,
        AdminModule.whiteLabel,
        AdminModule.platformOperations,
        AdminModule.dynamicWidgets,
      ]) {
        expect(
          SchoolBuildScope.isModuleHidden(module),
          isTrue,
          reason: '$module should be hidden in the school build',
        );
      }
    });

    test('chain-gated modules are NOT SchoolBuildScope-hidden (gated at runtime)',
        () {
      // M3: organization-builder is no longer build-hidden — it is gated by
      // chain status (ChainScope), so chain orgs can reach it.
      expect(
        SchoolBuildScope.isModuleHidden(AdminModule.organizationBuilder),
        isFalse,
      );
    });

    test('core school modules and kept multi-school modules are NOT hidden', () {
      for (final module in [
        AdminModule.admin,
        AdminModule.admissions,
        AdminModule.finance,
        AdminModule.sis,
        AdminModule.hr,
        AdminModule.management,
        AdminModule.transport,
        AdminModule.hostel, // CODE-7: module stays (residence-lite); only leave/gate-pass routes hidden
        AdminModule.library,
        AdminModule.inventory,
        AdminModule.controlCenter, // multi-school: KEPT
        AdminModule.director, // multi-school: KEPT
      ]) {
        expect(
          SchoolBuildScope.isModuleHidden(module),
          isFalse,
          reason: '$module must stay visible in the school build',
        );
      }
    });

    test('owner scope deferrals (CODE-7/8, 2026-07-13): Alumni hidden; Hostel leave/gate-pass hidden',
        () {
      // CODE-8: Alumni deferred for pilot — module dropped from nav, whole
      // /alumni/* surface route-hidden.
      expect(SchoolBuildScope.isModuleHidden(AdminModule.alumni), isTrue);
      expect(SchoolBuildScope.isRouteHidden(RouteNames.alumni), isTrue);
      expect(SchoolBuildScope.isRouteHidden(RouteNames.alumniRegistry), isTrue,
          reason: 'nested /alumni/* sub-routes must also be blocked');
      // CODE-7: Hostel residence-lite — leave-management + visitor/gate-pass
      // sub-features hidden, but the occupancy core stays reachable.
      expect(SchoolBuildScope.isRouteHidden(RouteNames.hostelLeave), isTrue);
      expect(SchoolBuildScope.isRouteHidden(RouteNames.hostelVisitors), isTrue);
      for (final kept in [
        RouteNames.hostelDashboard,
        RouteNames.hostelStudents,
        RouteNames.hostelRooms,
        RouteNames.hostelAttendance,
        RouteNames.hostelReports,
      ]) {
        expect(SchoolBuildScope.isRouteHidden(kept), isFalse,
            reason: '$kept is residence-lite occupancy — must stay reachable');
      }
    });

    test('hidden routes (incl. nested sub-routes) are blocked', () {
      for (final route in [
        RouteNames.salon,
        '${RouteNames.salon}/customers',
        RouteNames.healthcare,
        RouteNames.restaurant,
        RouteNames.accommodation,
        RouteNames.whiteLabel,
        RouteNames.platformOperations,
        RouteNames.dynamicWidgets,
        RouteNames.resourceOptimization,
        RouteNames.schoolMemories,
        RouteNames.principalCommand,
      ]) {
        expect(
          SchoolBuildScope.isRouteHidden(route),
          isTrue,
          reason: '$route should be hidden in the school build',
        );
      }
    });

    test('growthPlatform (Marketing engine) is surfaced, not build-hidden (B6)',
        () {
      expect(SchoolBuildScope.isRouteHidden(RouteNames.growthPlatform), isFalse,
          reason:
              'B6 surfaced the Marketing engine; it is entitlement-gated, not hidden');
    });

    test('kept school + multi-school routes are NOT blocked', () {
      for (final route in [
        RouteNames.financeDashboard,
        RouteNames.sisDashboard,
        RouteNames.controlCenterDashboard,
        RouteNames.directorDashboard,
        RouteNames.multiSchoolPortfolio,
        RouteNames.operationsHub, // real ops hub (shares viewOperationsHub)
      ]) {
        expect(
          SchoolBuildScope.isRouteHidden(route),
          isFalse,
          reason: '$route must remain reachable in the school build',
        );
      }
    });

    test('chain-gated routes are NOT SchoolBuildScope-hidden (gated at runtime)',
        () {
      // M3: these are gated by chain status (ChainScope) at runtime, not by the
      // static school-build switch — so chain orgs can reach them.
      for (final route in [
        RouteNames.franchise,
        RouteNames.organizationBuilder,
        '${RouteNames.organizationBuilder}/interview',
      ]) {
        expect(
          SchoolBuildScope.isRouteHidden(route),
          isFalse,
          reason: '$route is chain-gated, not build-hidden',
        );
      }
    });
  });
}
