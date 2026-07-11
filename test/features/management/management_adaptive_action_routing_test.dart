import 'package:akshara_erp/features/management/management_adaptive_action_routing.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('managementAdaptiveActionRoute — W2.7 ops-module deep links', () {
    // supabase/functions/_shared/intelligence/priority/recommendation_actions.ts
    // — every ops_* deepLink emitted, verbatim.
    test('finance recovery call queue -> collection follow-up (Defaulters), '
        'more specific than the generic /finance prefix', () {
      expect(
        managementAdaptiveActionRoute('/finance/recovery/call-queue'),
        RouteNames.financeDefaulters,
      );
    });

    test('inventory low-stock -> inventory stock screen', () {
      expect(
        managementAdaptiveActionRoute('/inventory/stock/low-stock'),
        RouteNames.inventoryStock,
      );
    });

    test('transport vehicle document expiry -> transport vehicles', () {
      expect(
        managementAdaptiveActionRoute('/transport/vehicles'),
        RouteNames.transportVehicles,
      );
    });

    test('HR expiring documents -> HR reports (closest existing screen)', () {
      expect(
        managementAdaptiveActionRoute('/hr/documents/expiring'),
        RouteNames.hrReports,
      );
    });

    test('HR probation ending -> HR reports (closest existing screen)', () {
      expect(
        managementAdaptiveActionRoute('/hr/probation/ending'),
        RouteNames.hrReports,
      );
    });

    test('library overdue -> library overdue screen', () {
      expect(
        managementAdaptiveActionRoute('/library/overdue'),
        RouteNames.libraryOverdue,
      );
    });
  });

  group('managementAdaptiveActionRoute — pre-existing W2.0 deep links (no regression)', () {
    test('a generic /finance deep link still falls back to the finance overview', () {
      expect(managementAdaptiveActionRoute('/finance/dashboard'), RouteNames.managementFinance);
    });

    test('analytics -> management analytics', () {
      expect(managementAdaptiveActionRoute('/analytics/attendance'), RouteNames.managementAnalytics);
      expect(managementAdaptiveActionRoute('/analytics/dashboard'), RouteNames.managementAnalytics);
    });

    test('timetable -> management timetable', () {
      expect(managementAdaptiveActionRoute('/timetable/conflicts'), RouteNames.managementTimetable);
    });

    test('anything mentioning approval -> management approvals', () {
      expect(managementAdaptiveActionRoute('/some/approval/queue'), RouteNames.managementApprovals);
    });
  });

  group('managementAdaptiveActionRoute — unmapped', () {
    test('an unknown deep link falls back to the intelligence hub, never a dead tap', () {
      expect(managementAdaptiveActionRoute('/unknown/thing'), RouteNames.managementIntelligence);
    });
  });
}
