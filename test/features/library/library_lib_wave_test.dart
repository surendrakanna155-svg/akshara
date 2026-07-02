import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/library/catalog/library_catalog_screen.dart';
import 'package:akshara_erp/features/library/dashboard/library_dashboard_screen.dart';
import 'package:akshara_erp/features/library/issues/library_issues_screen.dart';
import 'package:akshara_erp/features/library/library_providers.dart';
import 'package:akshara_erp/features/library/library_workflow_actions.dart';
import 'package:akshara_erp/features/library/overdue/library_overdue_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// Warms the members + catalog providers (which the issue dialog reads) and
/// exposes a button that opens [showIssueLibraryBookDialog] — the same call the
/// real dashboard / issues screens make.
class _IssueDialogHarness extends ConsumerWidget {
  const _IssueDialogHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch so both providers build + load before the dialog reads them.
    ref.watch(libraryMembersProvider);
    ref.watch(libraryCatalogProvider);
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: QaTestKeys.libraryIssueScanButton,
          onPressed: () => showIssueLibraryBookDialog(context, ref),
          child: const Text('Open issue'),
        ),
      ),
    );
  }
}

/// LIB-1 … LIB-D1 — UI wiring widget tests for the new library screens/actions.
///
/// The export service is faked so the platform `printing` plugin is never driven;
/// each grid call is recorded so we can assert the export path fired.
class _FakeExportService extends AksharaReportExportService {
  const _FakeExportService(this.calls);

  final List<String> calls;

  @override
  Future<void> shareGridCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    calls.add('csv:$filename:${rows.length}');
  }

  @override
  Future<void> shareGridPdf({
    required String filename,
    required String reportTitle,
    required String moduleLabel,
    required List<String> headers,
    required List<List<String>> rows,
    String? generatedAtLabel,
    int? rightAlignFrom,
  }) async {
    calls.add('pdf:$filename:${rows.length}');
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(overrides),
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
  group('LIB-2 — catalog edit / delete / import', () {
    testWidgets('Edit opens a prefilled dialog and saves an update',
        (tester) async {
      await _pump(tester, const LibraryCatalogScreen());

      await tester.ensureVisible(
        find.byKey(QaTestKeys.libraryEditBookButton('bk_1')),
      );
      await tester.tap(find.byKey(QaTestKeys.libraryEditBookButton('bk_1')));
      await tester.pumpAndSettle();

      // Prefilled with the current title.
      expect(find.text('Edit book'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Pride and Prejudice'),
          findsOneWidget);

      await tester.tap(find.byKey(QaTestKeys.libraryEditBookDialogSubmitButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.libraryEditBookSuccessSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('Delete a book on an active loan is rejected gracefully',
        (tester) async {
      await _pump(tester, const LibraryCatalogScreen());

      // bk_1 (Pride and Prejudice) is on loan iss_4 — deletion must be rejected.
      await tester.ensureVisible(
        find.byKey(QaTestKeys.libraryDeleteBookButton('bk_1')),
      );
      await tester.tap(find.byKey(QaTestKeys.libraryDeleteBookButton('bk_1')));
      await tester.pumpAndSettle();

      expect(find.text('Delete book'), findsOneWidget);
      await tester.tap(find.byKey(QaTestKeys.libraryDeleteBookConfirmButton));
      await tester.pumpAndSettle();

      // No success snackbar — the guardrail rejection is surfaced as a friendly
      // SnackBar (a SnackBar is shown, but not the success one).
      expect(
        find.byKey(QaTestKeys.libraryDeleteBookSuccessSnackbar),
        findsNothing,
      );
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Delete a book with no active loan succeeds', (tester) async {
      await _pump(tester, const LibraryCatalogScreen());

      // bk_5 (Concepts of Physics) is not referenced by any seeded loan.
      await tester.ensureVisible(
        find.byKey(QaTestKeys.libraryDeleteBookButton('bk_5')),
      );
      await tester.tap(find.byKey(QaTestKeys.libraryDeleteBookButton('bk_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(QaTestKeys.libraryDeleteBookConfirmButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.libraryDeleteBookSuccessSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('Import sheet parses pasted CSV and reports the result',
        (tester) async {
      await _pump(tester, const LibraryCatalogScreen());

      await tester.tap(find.byKey(QaTestKeys.libraryImportBooksButton));
      await tester.pumpAndSettle();

      expect(find.text('Import books (CSV)'), findsOneWidget);
      await tester.enterText(
        find.byKey(QaTestKeys.libraryImportBooksTextField),
        'The Alchemist,Paulo Coelho,978-0-06-112241-5,Fiction,3,FIC-2',
      );
      await tester.tap(find.byKey(QaTestKeys.libraryImportBooksSubmitButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.libraryImportBooksResultSnackbar),
        findsOneWidget,
      );
      expect(find.textContaining('Imported 1'), findsOneWidget);
    });

    testWidgets('Import reports a per-row failure for a duplicate ISBN',
        (tester) async {
      await _pump(tester, const LibraryCatalogScreen());

      await tester.tap(find.byKey(QaTestKeys.libraryImportBooksButton));
      await tester.pumpAndSettle();

      // 978-0-14-143951-8 is bk_1's ISBN — must fail as a duplicate.
      await tester.enterText(
        find.byKey(QaTestKeys.libraryImportBooksTextField),
        'Dup,Someone,978-0-14-143951-8,Fiction,1,X-1',
      );
      await tester.tap(find.byKey(QaTestKeys.libraryImportBooksSubmitButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 failed'), findsOneWidget);
    });
  });

  group('LIB-3 — manual ISBN entry on the issue dialog', () {
    testWidgets('Unknown / zero-stock ISBN surfaces a friendly error',
        (tester) async {
      // The issue dialog reads members + catalog; warm both so it opens.
      await _pump(tester, const _IssueDialogHarness());

      await tester.tap(find.byKey(QaTestKeys.libraryIssueScanButton));
      await tester.pumpAndSettle();

      expect(find.text('Issue book'), findsOneWidget);
      // bk_3 (To Kill a Mockingbird) has 0 available copies — it is not in the
      // issuable list, so keying its ISBN must fail with a friendly message.
      await tester.enterText(
        find.byKey(QaTestKeys.libraryIssueIsbnField),
        '978-0-06-112008-4',
      );
      await tester.pumpAndSettle();
      // Tap the "Find by ISBN" suffix action on the ISBN field.
      await tester.tap(
        find.descendant(
          of: find.byKey(QaTestKeys.libraryIssueIsbnField),
          matching: find.byIcon(Icons.search),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No available book with ISBN'), findsOneWidget);
    });
  });

  group('LIB-4 — renew an active loan', () {
    testWidgets('Renew is offered on active loans and confirms with a snackbar',
        (tester) async {
      await _pump(tester, const LibraryIssuesScreen());

      // iss_2 (The Great Gatsby) is active — renew is available.
      final renewBtn = find.byKey(QaTestKeys.libraryRenewLoanButton('iss_2'));
      expect(renewBtn, findsOneWidget);
      await tester.ensureVisible(renewBtn);
      await tester.tap(renewBtn);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.libraryRenewLoanSuccessSnackbar),
        findsOneWidget,
      );
    });

    testWidgets('Renew is NOT offered on an overdue loan', (tester) async {
      await _pump(tester, const LibraryIssuesScreen());

      // iss_1 is overdue — only Return is shown, no Renew.
      expect(
        find.byKey(QaTestKeys.libraryRenewLoanButton('iss_1')),
        findsNothing,
      );
    });
  });

  group('LIB-5 — send overdue reminders', () {
    testWidgets('Reminders button reports the recipient count', (tester) async {
      await _pump(tester, const LibraryIssuesScreen());

      final btn = find.byKey(QaTestKeys.librarySendRemindersButton);
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.librarySendRemindersSuccessSnackbar),
        findsOneWidget,
      );
      // Two overdue loans (iss_1 + iss_4) are seeded.
      expect(find.text('Reminders sent to 2'), findsOneWidget);
    });
  });

  group('LIB-1 — overdue screen + export', () {
    testWidgets('Overdue screen lists overdue loans', (tester) async {
      await _pump(tester, const LibraryOverdueScreen());

      // "Overdue loans" appears in the breadcrumb + section header.
      expect(find.text('Overdue loans'), findsWidgets);
      expect(find.text('Arjun Patel'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
    });

    testWidgets('CSV export fires the grid export + feedback', (tester) async {
      final calls = <String>[];
      await _pump(
        tester,
        const LibraryOverdueScreen(),
        overrides: [
          aksharaReportExportServiceProvider
              .overrideWithValue(_FakeExportService(calls)),
        ],
      );

      final csvBtn = find.byKey(QaTestKeys.libraryOverdueExportCsvButton);
      await tester.ensureVisible(csvBtn);
      await tester.tap(csvBtn);
      await tester.pumpAndSettle();

      // Two overdue rows exported.
      expect(calls, contains('csv:library_overdue_loans:2'));
      expect(find.textContaining('Overdue loans CSV ready'), findsOneWidget);
    });
  });

  group('LIB-D1 — settings', () {
    testWidgets('Settings dialog opens from the dashboard and saves guardrails',
        (tester) async {
      await _pump(tester, const LibraryDashboardScreen());

      final settingsBtn = find.byKey(QaTestKeys.librarySettingsButton);
      expect(settingsBtn, findsOneWidget);
      await tester.ensureVisible(settingsBtn);
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      expect(find.text('Library settings'), findsOneWidget);
      expect(
        find.byKey(QaTestKeys.librarySettingsMaxBooksField),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(QaTestKeys.librarySettingsMaxRenewalsField),
        '3',
      );
      await tester.tap(find.byKey(QaTestKeys.librarySettingsSubmitButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(QaTestKeys.librarySettingsSuccessSnackbar),
        findsOneWidget,
      );
      expect(find.textContaining('3 renewals'), findsOneWidget);
    });
  });
}
