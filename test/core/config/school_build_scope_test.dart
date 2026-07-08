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
        AdminModule.transport,
        AdminModule.hostel,
        AdminModule.library,
        AdminModule.inventory,
        AdminModule.alumni,
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

    test('management executive-dashboard module is hidden until built', () {
      // Owner decision 2026-07-09: MG-01→MG-08 is unbuilt (its primary nav
      // destination is an empty placeholder), so the sidebar entry is hidden.
      // Nav-only — the real /management/approvals surface keeps its own route.
      expect(SchoolBuildScope.isModuleHidden(AdminModule.management), isTrue);
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
