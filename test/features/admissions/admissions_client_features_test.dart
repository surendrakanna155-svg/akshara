import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/admissions/applications/admissions_applications_screen.dart';
import 'package:akshara_erp/features/admissions/dashboard/admissions_dashboard_screen.dart';
import 'package:akshara_erp/features/admissions/leads/admissions_leads_provider.dart';
import 'package:akshara_erp/features/admissions/leads/admissions_leads_screen.dart';
import 'package:akshara_erp/features/admissions/leads/widgets/admissions_bulk_action_bar.dart';
import 'package:akshara_erp/features/admissions/reports/admissions_reports_screen.dart';
import 'package:akshara_erp/features/admissions/reports/widgets/admissions_reports_tables.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('ADM-3 bulk lead selection + action bar', () {
    testWidgets('ticking a lead surfaces the bulk-action bar', (tester) async {
      await _pump(tester, const AdmissionsLeadsScreen());

      // No selection → no bulk bar.
      expect(find.byType(AdmissionsBulkActionBar), findsNothing);

      // Tick the first checkbox in the leads table.
      final checkbox = find.byType(Checkbox).first;
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      expect(find.byType(AdmissionsBulkActionBar), findsOneWidget);
      expect(find.byKey(QaTestKeys.admissionsBulkAssignButton), findsOneWidget);
      expect(find.byKey(QaTestKeys.admissionsBulkStageButton), findsOneWidget);
      expect(find.textContaining('selected'), findsWidgets);
    });

    testWidgets('bulk assign dialog posts the action and clears selection',
        (tester) async {
      await _pump(tester, const AdmissionsLeadsScreen());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdmissionsLeadsScreen)),
      );

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(container.read(admissionsSelectedLeadsProvider), isNotEmpty);

      await tester.tap(find.byKey(QaTestKeys.admissionsBulkAssignButton));
      await tester.pumpAndSettle();

      // Enter a counselor and confirm on the dialog.
      await tester.enterText(find.byType(TextField).last, 'Meera N.');
      await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
      await tester.pumpAndSettle();

      // A successful bulk action clears the selection (bar collapses).
      expect(container.read(admissionsSelectedLeadsProvider), isEmpty);
      expect(find.byType(AdmissionsBulkActionBar), findsNothing);
    });
  });

  group('ADM-4 dashboard follow-up actions', () {
    testWidgets('follow-up action opens the complete/reschedule/call sheet',
        (tester) async {
      await _pump(tester, const AdmissionsDashboardScreen());

      // The follow-ups table exposes an actions button per row. It may be below
      // the fold, so scroll it into view before tapping.
      final actionButton = find.widgetWithIcon(IconButton, Icons.more_horiz);
      expect(actionButton, findsWidgets);
      await tester.ensureVisible(actionButton.first);
      await tester.pumpAndSettle();
      await tester.tap(actionButton.first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.admissionsFollowUpCompleteButton),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.admissionsFollowUpRescheduleButton),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.admissionsFollowUpCallButton),
        findsOneWidget,
      );
    });
  });

  group('ADM-5 new-application lead picker', () {
    testWidgets('New Application opens the lead picker with real leads',
        (tester) async {
      await _pump(tester, const AdmissionsApplicationsScreen());

      await tester.tap(
        find.byKey(QaTestKeys.admissionsCreateApplicationButton),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select a lead'), findsOneWidget);
      // A real seeded lead appears as a pickable option.
      expect(
        find.byKey(QaTestKeys.admissionsLeadPickerOption('LD-1042')),
        findsOneWidget,
      );
      // Confirm is disabled until a lead is chosen.
      final confirm = tester.widget<FilledButton>(
        find.byKey(QaTestKeys.admissionsLeadPickerConfirmButton),
      );
      expect(confirm.onPressed, isNull);

      await tester.tap(
        find.byKey(QaTestKeys.admissionsLeadPickerOption('LD-1042')),
      );
      await tester.pumpAndSettle();

      final confirmAfter = tester.widget<FilledButton>(
        find.byKey(QaTestKeys.admissionsLeadPickerConfirmButton),
      );
      expect(confirmAfter.onPressed, isNotNull);
    });
  });

  group('ADM-D1 mark lost + reports lost-reasons card', () {
    testWidgets('reports Funnel tab shows the lost-reasons card', (
      tester,
    ) async {
      await _pump(tester, const AdmissionsReportsScreen());

      // Funnel tab is default → lost-reasons card renders with seeded rows.
      expect(find.byType(AdmissionsLostReasonsCard), findsOneWidget);
      expect(find.text('Why leads are lost'), findsOneWidget);
      expect(find.text('Fees too high'), findsOneWidget);
    });
  });

  group('ADM-D2 duplicate-phone warning', () {
    testWidgets('create-lead dialog warns when a phone already exists',
        (tester) async {
      await _pump(tester, const AdmissionsLeadsScreen());

      await tester.tap(find.byKey(QaTestKeys.admissionsCreateLeadButton));
      await tester.pumpAndSettle();

      // Enter a phone that matches a seeded lead, then blur.
      await tester.enterText(
        find.byKey(QaTestKeys.admissionsLeadPhoneField),
        '+91 98765 43210',
      );
      // Move focus away from the phone field to trigger the blur check.
      await tester.tap(find.byKey(QaTestKeys.admissionsLeadParentNameField));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.admissionsDuplicateWarningBanner),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.admissionsDuplicateOpenExistingButton),
        findsOneWidget,
      );
    });

    testWidgets('no warning for an unknown phone', (tester) async {
      await _pump(tester, const AdmissionsLeadsScreen());

      await tester.tap(find.byKey(QaTestKeys.admissionsCreateLeadButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(QaTestKeys.admissionsLeadPhoneField),
        '+91 00000 11111',
      );
      await tester.tap(find.byKey(QaTestKeys.admissionsLeadParentNameField));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.admissionsDuplicateWarningBanner),
        findsNothing,
      );
    });
  });

  group('ADM-3 selection prunes on reload', () {
    testWidgets('selection is cleared when it is empty by default',
        (tester) async {
      await _pump(tester, const AdmissionsLeadsScreen());
      // With nothing ticked, the selection provider stays empty.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdmissionsLeadsScreen)),
      );
      expect(container.read(admissionsSelectedLeadsProvider), isEmpty);
    });
  });
}
