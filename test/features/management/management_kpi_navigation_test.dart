import 'package:akshara_erp/features/management/management_kpi_navigation.dart';
import 'package:akshara_erp/features/management/management_models.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('defaultManagementKpiDrillRoute', () {
    test('maps revenue to finance reports', () {
      expect(defaultManagementKpiDrillRoute('revenue_mtd'), RouteNames.financeReports);
    });

    test('maps defaulters to collection follow-up', () {
      expect(defaultManagementKpiDrillRoute('fee_defaulters'), RouteNames.financeDefaulters);
      expect(defaultManagementKpiDrillRoute('fee_collection'), RouteNames.financeDefaulters);
    });

    test('maps admissions to admissions pipeline', () {
      expect(defaultManagementKpiDrillRoute('new_admissions'), RouteNames.managementAdmissions);
    });

    test('maps attendance to student success intelligence', () {
      expect(defaultManagementKpiDrillRoute('attendance'), RouteNames.studentSuccessIntelligence);
    });

    test('maps academic KPIs to exam intelligence', () {
      expect(defaultManagementKpiDrillRoute('pass_rate'), RouteNames.examIntelligence);
      expect(defaultManagementKpiDrillRoute('at_risk'), RouteNames.examIntelligence);
    });
  });

  group('navigateManagementKpiDrill', () {
    Future<void> pumpRouter(
      WidgetTester tester,
      ManagementKpi kpi,
      void Function(String?) onNavigate,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => navigateManagementKpiDrill(context, kpi),
                child: const Text('Drill'),
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.financeReports,
            builder: (context, state) {
              onNavigate(state.uri.path);
              return const Scaffold(body: Text('Reports'));
            },
          ),
          GoRoute(
            path: RouteNames.financeDefaulters,
            builder: (context, state) {
              onNavigate(state.uri.path);
              return const Scaffold(body: Text('Defaulters'));
            },
          ),
          GoRoute(
            path: RouteNames.managementAdmissions,
            builder: (context, state) {
              onNavigate(state.uri.path);
              return const Scaffold(body: Text('Admissions'));
            },
          ),
          GoRoute(
            path: RouteNames.studentSuccessIntelligence,
            builder: (context, state) {
              onNavigate(state.uri.path);
              return const Scaffold(body: Text('Attendance intel'));
            },
          ),
          GoRoute(
            path: RouteNames.examIntelligence,
            builder: (context, state) {
              onNavigate(state.uri.path);
              return const Scaffold(body: Text('Academic intel'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Drill'));
      await tester.pumpAndSettle();
    }

    testWidgets('uses explicit drillRoute when set', (tester) async {
      String? captured;
      await pumpRouter(
        tester,
        const ManagementKpi(
          id: 'custom',
          value: '1',
          label: 'Custom',
          icon: Icons.analytics,
          accentName: 'primary',
          drillRoute: RouteNames.financeReports,
        ),
        (path) => captured = path,
      );
      expect(captured, RouteNames.financeReports);
    });

    testWidgets('falls back to default route by id', (tester) async {
      String? captured;
      await pumpRouter(
        tester,
        const ManagementKpi(
          id: 'fee_defaulters',
          value: '47',
          label: 'Fee Defaulters',
          icon: Icons.warning_amber_outlined,
          accentName: 'error',
        ),
        (path) => captured = path,
      );
      expect(captured, RouteNames.financeDefaulters);
    });
  });

  test('managementKpiIsDrillable reflects route availability', () {
    expect(
      managementKpiIsDrillable(
        const ManagementKpi(
          id: 'revenue_mtd',
          value: '₹1Cr',
          label: 'Revenue',
          icon: Icons.trending_up,
          accentName: 'success',
        ),
      ),
      isTrue,
    );
    expect(
      managementKpiIsDrillable(
        const ManagementKpi(
          id: 'unknown_metric',
          value: '0',
          label: 'Unknown',
          icon: Icons.help_outline,
          accentName: 'neutral',
        ),
      ),
      isFalse,
    );
  });
}
