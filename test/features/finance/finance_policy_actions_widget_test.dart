import 'dart:typed_data';

import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/finance/collections/finance_collections_screen.dart';
import 'package:akshara_erp/features/finance/invoices/finance_invoice_management_section.dart';
import 'package:akshara_erp/features/finance/invoices/finance_invoices_provider.dart';
import 'package:akshara_erp/features/finance/policy/finance_policy_provider.dart';
import 'package:akshara_erp/features/finance/student_accounts/finance_student_accounts_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// FIN-D1 / FIN-D3 / FIN-D5 / FIN-2 — verifies the newly-wired collections
/// policy actions (accrue late fees, day-close lock) and the student-ledger
/// statement export are user-reachable and drive their providers/services.
///
/// The export service is faked so the platform `printing` plugin (layoutPdf /
/// sharePdf) is not driven in the test.
class _FakeExportService extends AksharaReportExportService {
  const _FakeExportService(this.calls);

  final List<String> calls;

  @override
  Future<Uint8List> buildGridReportPdf({
    required String reportTitle,
    required String moduleLabel,
    required List<String> headers,
    required List<List<String>> rows,
    String? generatedAtLabel,
    int? rightAlignFrom,
  }) async {
    calls.add('buildGridPdf:$reportTitle:${rows.length}');
    return Uint8List(0);
  }

  @override
  Future<void> previewPdf({
    required String documentName,
    required Uint8List bytes,
  }) async {
    calls.add('previewPdf:$documentName');
  }

  @override
  Future<void> shareGridCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    calls.add('shareGridCsv:$filename:${rows.length}');
  }
}

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpCollections(WidgetTester tester, List<String> calls) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        aksharaReportExportServiceProvider
            .overrideWithValue(_FakeExportService(calls)),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const FinanceCollectionsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

Future<void> _pumpStudentAccounts(
  WidgetTester tester,
  List<String> calls,
) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        aksharaReportExportServiceProvider
            .overrideWithValue(_FakeExportService(calls)),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const FinanceStudentAccountsScreen(),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

Future<void> _pumpInvoiceSection(WidgetTester tester) async {
  _useDesktopViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: FinanceInvoiceManagementSection(),
          ),
        ),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('FIN-D · Finance collections policy actions', () {
    testWidgets('the day-close control renders with a Close day action',
        (tester) async {
      await _pumpCollections(tester, []);

      expect(find.text('Day-close lock'), findsOneWidget);
      expect(find.text('No day closed yet'), findsOneWidget);
      expect(find.byKey(QaTestKeys.financeCloseDayButton), findsOneWidget);
      // No day closed yet → no Reopen action.
      expect(find.byKey(QaTestKeys.financeReopenDayButton), findsNothing);
    });

    testWidgets('Close day locks the day and surfaces the Reopen action',
        (tester) async {
      await _pumpCollections(tester, []);

      await tester.tap(find.byKey(QaTestKeys.financeCloseDayButton));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.financeDayCloseSnackbar), findsOneWidget);
      expect(find.textContaining('Day closed'), findsOneWidget);
      // The read invalidated → a closed day is now shown with a Reopen action.
      expect(find.textContaining('Last closed day'), findsOneWidget);
      expect(find.byKey(QaTestKeys.financeReopenDayButton), findsOneWidget);
    });

    testWidgets('the policy menu exposes accrue + cancelled-register actions',
        (tester) async {
      await _pumpCollections(tester, []);

      await tester.tap(find.byKey(QaTestKeys.financeCollectionsPolicyMenu));
      await tester.pumpAndSettle();

      expect(find.byKey(QaTestKeys.financeAccrueLateFeesButton), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.financeCancelledRegisterButton),
        findsOneWidget,
      );
    });

    testWidgets('Accrue late fees runs the accrual and shows a summary snackbar',
        (tester) async {
      await _pumpCollections(tester, []);

      await tester.tap(find.byKey(QaTestKeys.financeCollectionsPolicyMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(QaTestKeys.financeAccrueLateFeesButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.financeAccrueLateFeesSnackbar),
        findsOneWidget,
      );
      expect(find.textContaining('Accrued late fee on'), findsOneWidget);
    });

    testWidgets(
        'Cancelled register export shows an info snackbar when register is empty',
        (tester) async {
      final calls = <String>[];
      await _pumpCollections(tester, calls);

      await tester.tap(find.byKey(QaTestKeys.financeCollectionsPolicyMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(QaTestKeys.financeCancelledRegisterButton));
      await tester.pumpAndSettle();

      // Mock register is empty by default → info snackbar, no CSV share.
      expect(find.text('No cancelled collections to export'), findsOneWidget);
      expect(calls.any((c) => c.startsWith('shareGridCsv:')), isFalse);
    });
  });

  group('FIN-2 · Student ledger statement export', () {
    testWidgets('Export statement builds a ledger PDF, previews, and confirms',
        (tester) async {
      final calls = <String>[];
      await _pumpStudentAccounts(tester, calls);

      final exportButton =
          find.byKey(QaTestKeys.financeExportStatementButton);
      expect(exportButton, findsOneWidget);
      await tester.ensureVisible(exportButton);
      await tester.pumpAndSettle();
      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      expect(calls.any((c) => c.startsWith('buildGridPdf:')), isTrue);
      expect(calls.any((c) => c.startsWith('previewPdf:')), isTrue);
      expect(
        find.byKey(QaTestKeys.financeExportStatementSnackbar),
        findsOneWidget,
      );
      expect(find.textContaining('Fee statement ready'), findsOneWidget);
    });
  });

  group('FIN-D5 · Invoice waive-late-fee action', () {
    testWidgets(
        'accruing a late fee surfaces the indicator + waive action, and '
        'waiving with a reason succeeds', (tester) async {
      await _pumpInvoiceSection(tester);

      // No late fee accrued yet → no waive action.
      expect(find.textContaining('Late fee:'), findsNothing);

      // Accrue late fees against the shared mock store, then refresh invoices.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FinanceInvoiceManagementSection)),
      );
      final result =
          await container.read(accrueLateFeesProvider.notifier).execute();
      expect(result, isNotNull);
      expect(result!.accruedCount, greaterThan(0));
      container.invalidate(financeInvoicesFutureProvider);
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();

      // The late-fee indicator + waive action are now shown.
      expect(find.textContaining('Late fee:'), findsWidgets);
      final waiveButton =
          find.widgetWithText(OutlinedButton, 'Waive late fee').first;
      await tester.ensureVisible(waiveButton);
      await tester.pumpAndSettle();
      await tester.tap(waiveButton);
      await tester.pumpAndSettle();

      // Empty reason must not submit.
      await tester.tap(find.byKey(QaTestKeys.financeWaiveLateFeeConfirmButton));
      await tester.pumpAndSettle();
      expect(
        find.byKey(QaTestKeys.financeWaiveLateFeeConfirmButton),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextField).first,
        'Waived per principal approval',
      );
      await tester.pump();
      await tester.tap(find.byKey(QaTestKeys.financeWaiveLateFeeConfirmButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.financeWaiveLateFeeSnackbar),
        findsOneWidget,
      );
      expect(find.textContaining('Late fee waived'), findsOneWidget);
    });
  });
}
