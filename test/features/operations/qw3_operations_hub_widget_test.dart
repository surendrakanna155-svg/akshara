import 'dart:async';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/operations/operations_hub_screen.dart';
import 'package:akshara_erp/features/phase5/phase5_models.dart';
import 'package:akshara_erp/features/phase5/phase5_providers.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-024 (Operations Hub cockpit render + loading/empty/error states)
/// and QA-F-025 (Dismiss alert + Complete action mutations).
/// `operations_hub_screen.dart` had no widget test. The screen reads
/// `operationsHubProvider` (demo repo) and mutates via the
/// dismiss/complete AsyncNotifiers (RBAC-gated; the demo super-admin auth from
/// `erpWidgetTestStaffAuth()` carries manageManagement + viewOperationsHub).

Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const OperationsHubScreen(),
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

/// Empty snapshot for the empty-state assertion (no alerts / no actions).
OperationsHubSnapshot _emptySnapshot() => const OperationsHubSnapshot(
      schoolHealth: 100,
      dailySummary: OperationsDailySummary(
        attendancePct: 100,
        collectionsToday: 0,
        communicationsToday: 0,
        criticalAlerts: 0,
      ),
      criticalAlerts: [],
      pendingActions: [],
      widgets: OperationsWidgets(
        todayAttendance: {},
        todayCollections: {},
        todayCommunications: {},
        studentRiskAlerts: 0,
        employeeRiskAlerts: 0,
        inventoryAlerts: 0,
        feeAlerts: 0,
      ),
    );

void main() {
  group('QA-F-024 · OperationsHubScreen render + states', () {
    testWidgets('renders the cockpit sections from the demo snapshot',
        (tester) async {
      await _pump(tester);

      // Key cockpit sections: health, daily summary, alerts, actions, widgets.
      expect(find.text('School Operations Hub'), findsOneWidget);
      expect(find.text('School Health'), findsOneWidget);
      expect(find.text('82/100'), findsOneWidget);
      expect(find.text('Daily Summary'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Collections today'), findsOneWidget);
      expect(find.text('Critical Alerts'), findsOneWidget);
      expect(find.text('Pending Actions'), findsOneWidget);
      // Seeded demo alert + action rows.
      expect(find.text('2 high-risk students'), findsOneWidget);
      expect(find.text('4 distributions pending'), findsOneWidget);
    });

    testWidgets('shows the loading state while the hub future is pending',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          // Never-completing future keeps the provider in its loading branch.
          operationsHubProvider.overrideWith(
            (ref) => Completer<OperationsHubSnapshot>().future,
          ),
        ],
        settle: false,
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
      expect(find.text('School Health'), findsNothing);
    });

    testWidgets('shows the empty states when there are no alerts or actions',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          operationsHubProvider
              .overrideWith((ref) async => _emptySnapshot()),
        ],
      );

      expect(find.byType(AksharaEmptyState), findsNWidgets(2));
      expect(
        find.textContaining('No critical alerts'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No pending actions'),
        findsOneWidget,
      );
    });

    testWidgets('shows the error state when the hub future fails',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          operationsHubProvider.overrideWith(
            (ref) async => throw Exception('boom'),
          ),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(find.text('Unable to load operations hub.'), findsOneWidget);
    });
  });

  group('QA-F-025 · OperationsHub dismiss alert + complete action', () {
    testWidgets('tapping Dismiss removes the alert and surfaces a snackbar',
        (tester) async {
      await _pump(tester);

      expect(find.text('2 high-risk students'), findsOneWidget);

      // Dismiss the first seeded alert (id: student-risk).
      await tester.tap(
        find.byKey(QaTestKeys.operationsHubDismissAlertButton('student-risk')),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // Optimistic mutation + invalidate → the alert row is gone.
      expect(find.text('2 high-risk students'), findsNothing);
      // The other seeded alert remains.
      expect(find.text('6 critical fee defaulters'), findsOneWidget);
      // Confirmation snackbar fired.
      expect(find.text('Alert dismissed.'), findsOneWidget);
    });

    testWidgets('tapping Complete marks the action done and surfaces a snackbar',
        (tester) async {
      await _pump(tester);

      expect(find.text('4 distributions pending'), findsOneWidget);

      await tester.tap(
        find.byKey(
          QaTestKeys.operationsHubCompleteActionButton('inv-pending'),
        ),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(find.text('4 distributions pending'), findsNothing);
      expect(find.text('3 workflow approvals pending'), findsOneWidget);
      expect(find.text('Action marked as complete.'), findsOneWidget);
    });
  });
}
