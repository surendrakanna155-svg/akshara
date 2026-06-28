import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/director/director_models.dart';
import 'package:akshara_erp/features/director/director_reports_screen.dart';
import 'package:akshara_erp/features/director/director_revenue_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-055 — Director portfolio inputs + AI summary / board-pack (B8).
/// The chain owner enters per-school spend/expense/capacity (powering computed
/// Margin / ROI), generates an AI executive summary and exports a board pack.
/// Covers: computed Margin render, the metric-input editor form validation +
/// successful save, AI executive-summary generation, and board-pack export.

/// No-op export service so the board-pack "export" path can be exercised without
/// invoking the real PDF share plugin.
class _NoopReportExportService extends AksharaReportExportService {
  const _NoopReportExportService();
  @override
  Future<void> shareDirectorBoardPackPdf(DirectorBoardPack pack) async {}
}

/// SuperAdmin grants `manageDirectorPortal`, enabling the manage-gated controls
/// (Enter portfolio inputs, Generate summary, Export).
List<Override> _manageOverrides() => [
      userPermissionsProvider.overrideWithValue(
        UserPermissions.forRole(ErpRole.superAdmin),
      ),
    ];

Future<void> _pump(WidgetTester tester, Widget screen,
    {List<Override> overrides = const []}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([..._manageOverrides(), ...overrides]),
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
  group('QA-F-055 · Director portfolio inputs', () {
    testWidgets('revenue renders the computed margin and the manage entry',
        (tester) async {
      await _pump(tester, const DirectorRevenueScreen());

      // The Margin tile is the computed figure powered by entered inputs.
      expect(find.text('Margin'), findsOneWidget);
      // Manage permission surfaces the metric-input entry point.
      expect(
        find.byKey(QaTestKeys.directorManageInputsButton),
        findsOneWidget,
      );
    });

    testWidgets('metric-input editor blocks save until the form is valid',
        (tester) async {
      await _pump(tester, const DirectorRevenueScreen());

      await tester.tap(find.byKey(QaTestKeys.directorManageInputsButton));
      await tester.pumpAndSettle();

      // The editor sheet is open with the school selector + save action.
      expect(
        find.byKey(QaTestKeys.directorMetricInputSchoolField),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.directorMetricInputSaveButton),
        findsOneWidget,
      );

      // Submitting with no school and empty amounts surfaces validation errors
      // and does NOT show the saved snackbar.
      await tester.tap(find.byKey(QaTestKeys.directorMetricInputSaveButton));
      await tester.pumpAndSettle();

      expect(find.text('Select a school'), findsOneWidget);
      expect(find.text('Enter a number'), findsWidgets);
      expect(
        find.byKey(QaTestKeys.directorMetricInputSavedSnackbar),
        findsNothing,
      );
    });

    testWidgets('metric-input editor saves a valid draft',
        (tester) async {
      await _pump(tester, const DirectorRevenueScreen());

      await tester.tap(find.byKey(QaTestKeys.directorManageInputsButton));
      await tester.pumpAndSettle();

      // Choose the first school from the dropdown.
      await tester.tap(find.byKey(QaTestKeys.directorMetricInputSchoolField));
      await tester.pumpAndSettle();
      // Tap the first menu item that appears in the opened dropdown overlay.
      await tester.tap(find.byType(DropdownMenuItem<String>).last);
      await tester.pumpAndSettle();

      // Fill the three amount fields (month defaults to the current YYYY-MM).
      final amountFields = find.byType(TextFormField);
      // Field 0 = month, 1 = spend, 2 = expense, 3 = capacity.
      await tester.enterText(amountFields.at(1), '120000');
      await tester.enterText(amountFields.at(2), '90000');
      await tester.enterText(amountFields.at(3), '800');
      await tester.pump();

      await tester.tap(find.byKey(QaTestKeys.directorMetricInputSaveButton));
      await tester.pumpAndSettle();

      // Save succeeds → confirmation snackbar; the sheet pops closed.
      expect(
        find.byKey(QaTestKeys.directorMetricInputSavedSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('reports generates an AI executive summary',
        (tester) async {
      await _pump(tester, const DirectorReportsScreen());

      // Pre-generation placeholder prompt is shown.
      expect(
        find.text(
          'Generate a board-ready executive brief from aggregated portfolio metrics.',
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(QaTestKeys.directorReportsGenerateSummaryButton),
      );
      await tester.tap(
        find.byKey(QaTestKeys.directorReportsGenerateSummaryButton),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // The placeholder prompt is replaced by the generated summary text.
      expect(
        find.text(
          'Generate a board-ready executive brief from aggregated portfolio metrics.',
        ),
        findsNothing,
      );
    });

    testWidgets('reports exports a board pack and confirms',
        (tester) async {
      await _pump(
        tester,
        const DirectorReportsScreen(),
        overrides: [
          aksharaReportExportServiceProvider
              .overrideWithValue(const _NoopReportExportService()),
        ],
      );

      // The export button is enabled with manage permission; tap the first one.
      final exportButton = find.widgetWithText(TextButton, 'Export').first;
      await tester.ensureVisible(exportButton);
      await tester.tap(exportButton);
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.directorReportExportedSnackbar),
        findsOneWidget,
      );
    });
  });
}
