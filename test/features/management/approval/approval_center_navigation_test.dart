import 'package:akshara_erp/features/management/management_kpi_navigation.dart';
import 'package:akshara_erp/features/management/management_navigation.dart';
import 'package:akshara_erp/features/management/management_models.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Approval center navigation — M-D2 certification', () {
    test('pending_approvals KPI drills to managementApprovals', () {
      expect(
        defaultManagementKpiDrillRoute('pending_approvals'),
        RouteNames.managementApprovals,
      );
    });

    test('managementApprovals is registered in managementRoutes', () {
      expect(RouteNames.managementRoutes, contains(RouteNames.managementApprovals));
      expect(RouteNames.managementRoutes, contains(RouteNames.managementTasks));
    });

    test('managementScreenForLocation maps approvals to tasks tab', () {
      expect(
        managementScreenForLocation(RouteNames.managementApprovals),
        ManagementScreen.tasks,
      );
      expect(
        managementScreenForLocation(RouteNames.managementTasks),
        ManagementScreen.tasks,
      );
    });

    testWidgets('KPI drill navigates to approval center route', (tester) async {
      String? captured;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => navigateManagementKpiDrill(
                  context,
                  const ManagementKpi(
                    id: 'pending_approvals',
                    value: '7',
                    label: 'Pending Approvals',
                    icon: Icons.pending_actions_outlined,
                    accentName: 'warning',
                  ),
                ),
                child: const Text('Drill'),
              ),
            ),
          ),
          GoRoute(
            path: RouteNames.managementApprovals,
            builder: (context, state) {
              captured = state.uri.path;
              return const Scaffold(body: Text('Approval Center'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Drill'));
      await tester.pumpAndSettle();

      expect(captured, RouteNames.managementApprovals);
      expect(find.text('Approval Center'), findsOneWidget);
    });
  });
}
