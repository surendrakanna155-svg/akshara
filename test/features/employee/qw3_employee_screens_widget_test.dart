import 'dart:async';

import 'package:akshara_erp/features/employee/employee_360_screen.dart';
import 'package:akshara_erp/features/employee/employee_models.dart';
import 'package:akshara_erp/features/employee/employee_platform_screen.dart';
import 'package:akshara_erp/features/phase4/phase4_providers.dart';
import 'package:akshara_erp/features/phase5/phase5_models.dart';
import 'package:akshara_erp/features/phase5/phase5_providers.dart';
import 'package:akshara_erp/shared/widgets/akshara_error_state.dart';
import 'package:akshara_erp/shared/widgets/akshara_loading_state.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-051 — Employee 360 + Employee Platform screens render from demo
/// data, and degrade gracefully to the shared loading / error fallbacks when
/// their async providers are forced into those states.
///
/// Both screens were `AsyncValue`-driven with no widget coverage. State is
/// forced by overriding the screen's own FutureProviders (a never-completing
/// future for loading, a failed future for error) — the documented pattern.

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  if (settle) {
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  group('QA-F-051 · Employee360Screen', () {
    testWidgets('renders the profile, workload and insights from demo data',
        (tester) async {
      await _pump(tester, const Employee360Screen());

      expect(find.text('Employee 360'), findsOneWidget);
      // Demo profile: Priya Nair · Science · 72% workload / medium risk.
      expect(find.text('Priya Nair'), findsOneWidget);
      expect(find.text('Workload'), findsOneWidget);
      expect(find.textContaining('72%'), findsWidgets);
      expect(find.text('Insights'), findsOneWidget);
    });

    testWidgets('shows the loading fallback while the profile is pending',
        (tester) async {
      await _pump(
        tester,
        const Employee360Screen(),
        settle: false,
        overrides: [
          employee360Provider('emp_1').overrideWith(
            (ref) => Completer<Employee360Profile>().future,
          ),
        ],
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
    });

    testWidgets('shows the error fallback when the profile load fails',
        (tester) async {
      await _pump(
        tester,
        const Employee360Screen(),
        overrides: [
          employee360Provider('emp_1').overrideWith(
            (ref) => Future<Employee360Profile>.error(Exception('boom')),
          ),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
    });
  });

  group('QA-F-051 · EmployeePlatformScreen', () {
    testWidgets('renders the dashboard KPIs and the employee list',
        (tester) async {
      await _pump(tester, const EmployeePlatformScreen());

      expect(find.text('Employee Platform'), findsOneWidget);
      expect(find.text('Total employees'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Workload index'), findsOneWidget);
      // Demo employees from the phase-4 repo.
      expect(find.text('Meera Iyer'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
    });

    testWidgets('shows the loading fallback while the dashboard is pending',
        (tester) async {
      await _pump(
        tester,
        const EmployeePlatformScreen(),
        settle: false,
        overrides: [
          employeeDashboardProvider.overrideWith(
            (ref) => Completer<EmployeeDashboard>().future,
          ),
        ],
      );

      expect(find.byType(AksharaLoadingState), findsWidgets);
    });

    testWidgets('shows the error fallback when the employee list load fails',
        (tester) async {
      await _pump(
        tester,
        const EmployeePlatformScreen(),
        overrides: [
          employeesListProvider.overrideWith(
            (ref) => Future<List<EmployeeSummary>>.error(Exception('boom')),
          ),
        ],
      );

      expect(find.byType(AksharaErrorState), findsWidgets);
    });
  });
}
