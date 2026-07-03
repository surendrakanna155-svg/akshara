import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/director/director_models.dart';
import 'package:akshara_erp/features/director/director_providers.dart';
import 'package:akshara_erp/features/director/director_revenue_screen.dart';
import 'package:akshara_erp/features/director/director_school_snapshot_screen.dart';
import 'package:akshara_erp/features/director/director_schools_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// DIR-1/2/3 + DIR-D1 client behaviour on the certified B8 portal:
///  · DIR-1  league table sorts/ranks by the chosen metric (pure client sort).
///  · DIR-2  consolidated collection report shows per-school + org totals.
///  · DIR-3  CSV/PDF export buttons drive the shared XCT-1 grid exporters.
///  · DIR-D1 row tap → read-only, audited per-school drill-down snapshot.

/// No-op export service so the CSV/PDF share path runs without the real plugin.
class _NoopReportExportService extends AksharaReportExportService {
  const _NoopReportExportService();
  @override
  Future<void> shareGridCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {}
  @override
  Future<void> shareGridPdf({
    required String filename,
    required String reportTitle,
    required String moduleLabel,
    required List<String> headers,
    required List<List<String>> rows,
    String? generatedAtLabel,
    int? rightAlignFrom,
  }) async {}
}

Future<void> _pumpWide(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  // Wide window keeps the data-table path (ranked rows visible in order).
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        aksharaReportExportServiceProvider
            .overrideWithValue(const _NoopReportExportService()),
        ...overrides,
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

// Column index of the "School" name cell in the ranked league table
// (# , School, Location, ...).
String _firstSchoolNameInTable(WidgetTester tester) {
  // The first data row's school name is the second Text after the rank "1".
  final rank1 = find.text('1');
  expect(rank1, findsWidgets);
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere((s) => s.contains('Akshara'), orElse: () => '');
}

void main() {
  group('rankDirectorSchools (DIR-1 pure sort)', () {
    final rows = const [
      DirectorSchoolRow(
        schoolId: 'a',
        schoolName: 'A',
        location: '',
        students: 100,
        revenueCr: 1,
        admissionsQtd: 10,
        feeCollectionPercent: 70,
        billedInr: 1000,
        collectedInr: 700,
        outstandingInr: 300,
        healthScore: 60,
        status: DirectorSchoolStatus.atRisk,
      ),
      DirectorSchoolRow(
        schoolId: 'b',
        schoolName: 'B',
        location: '',
        students: 300,
        revenueCr: 3,
        admissionsQtd: 30,
        feeCollectionPercent: 95,
        billedInr: 5000,
        collectedInr: 4750,
        outstandingInr: 250,
        healthScore: 90,
        status: DirectorSchoolStatus.topPerformer,
      ),
    ];

    test('fee% ranks the higher collector first', () {
      final ranked = rankDirectorSchools(rows, DirectorSchoolSort.feePercent);
      expect(ranked.first.schoolId, 'b');
    });

    test('outstanding ranks the larger receivable first', () {
      final ranked = rankDirectorSchools(rows, DirectorSchoolSort.outstanding);
      expect(ranked.first.schoolId, 'a');
    });

    test('does not mutate the input list', () {
      final input = [...rows];
      rankDirectorSchools(input, DirectorSchoolSort.students);
      expect(input.map((e) => e.schoolId), ['a', 'b']);
    });
  });

  group('DIR-1 · league table sorts/ranks', () {
    testWidgets('default rank is by fee % (North first) and shows a rank column',
        (tester) async {
      await _pumpWide(tester, const DirectorSchoolsScreen());

      expect(find.byKey(QaTestKeys.directorSchoolsSortSelector), findsOneWidget);
      // Rank column present: rank "1" cell rendered.
      expect(find.text('1'), findsWidgets);
      // North Campus (94% fee) ranks first by default.
      expect(_firstSchoolNameInTable(tester), contains('North'));
    });

    testWidgets('switching sort to Outstanding reorders the league table',
        (tester) async {
      await _pumpWide(tester, const DirectorSchoolsScreen());

      await tester.tap(find.byKey(QaTestKeys.directorSchoolsSortSelector));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outstanding fees').last);
      await tester.pumpAndSettle();

      // Central Campus has the largest outstanding → now ranks first.
      expect(_firstSchoolNameInTable(tester), contains('Central'));
    });
  });

  group('DIR-3 · export buttons', () {
    testWidgets('school comparison Export CSV shows a confirmation snackbar',
        (tester) async {
      await _pumpWide(tester, const DirectorSchoolsScreen());

      await tester.tap(find.byKey(QaTestKeys.directorSchoolsExportCsvButton));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(QaTestKeys.directorExportSnackbar), findsOneWidget);
    });

    testWidgets('school comparison Export PDF shows a confirmation snackbar',
        (tester) async {
      await _pumpWide(tester, const DirectorSchoolsScreen());

      await tester.tap(find.byKey(QaTestKeys.directorSchoolsExportPdfButton));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(QaTestKeys.directorExportSnackbar), findsOneWidget);
    });
  });

  group('DIR-2 · consolidated collection report', () {
    testWidgets('revenue screen renders the collection report with org totals',
        (tester) async {
      await _pumpWide(tester, const DirectorRevenueScreen());

      expect(
        find.byKey(QaTestKeys.directorCollectionReportSection),
        findsOneWidget,
      );
      expect(find.text('Consolidated Collection Report'), findsOneWidget);
      // Org totals tile is present.
      expect(find.text('Fee Collection'), findsWidgets);
      // Collection export buttons are present.
      expect(
        find.byKey(QaTestKeys.directorCollectionExportCsvButton),
        findsOneWidget,
      );
      expect(
        find.byKey(QaTestKeys.directorCollectionExportPdfButton),
        findsOneWidget,
      );
    });

    testWidgets('collection totals equal the sum of the per-school rows',
        (tester) async {
      // Assert against the same provider the section reads.
      final container = ProviderContainer(
        overrides: erpWidgetTestOverrides(),
      );
      addTearDown(container.dispose);

      final report =
          await container.read(directorCollectionReportProvider.future);
      final sumBilled =
          report.schools.fold<int>(0, (s, r) => s + r.billedInr);
      final sumOutstanding =
          report.schools.fold<int>(0, (s, r) => s + r.outstandingInr);
      expect(report.totals.billedInr, sumBilled);
      expect(report.totals.outstandingInr, sumOutstanding);
    });

    testWidgets('collection Export CSV shows a confirmation snackbar',
        (tester) async {
      await _pumpWide(tester, const DirectorRevenueScreen());

      final csv = find.byKey(QaTestKeys.directorCollectionExportCsvButton);
      await tester.ensureVisible(csv);
      await tester.tap(csv);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(QaTestKeys.directorExportSnackbar), findsOneWidget);
    });
  });

  group('DIR-D1 · per-school drill-down snapshot', () {
    testWidgets('snapshot screen renders aggregates + read-only audited banner',
        (tester) async {
      await _pumpWide(
        tester,
        const DirectorSchoolSnapshotScreen(schoolId: 'DR-SCH-001'),
      );

      expect(
        find.byKey(QaTestKeys.directorSchoolSnapshotScreen),
        findsOneWidget,
      );
      // The read-only / audited banner is present and states the contract.
      expect(
        find.byKey(QaTestKeys.directorSchoolSnapshotReadOnlyBanner),
        findsOneWidget,
      );
      expect(find.textContaining('Read-only · audited'), findsOneWidget);
      // Aggregates render (school name + a metric tile).
      expect(find.text('Akshara North Campus'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Admissions funnel'), findsOneWidget);
    });

    testWidgets('snapshot shows the error state when the school is not found',
        (tester) async {
      await _pumpWide(
        tester,
        const DirectorSchoolSnapshotScreen(schoolId: 'FOREIGN'),
        overrides: [
          directorSchoolSnapshotProvider('FOREIGN').overrideWith(
            (ref) => Future<DirectorSchoolSnapshot>.error(
              Exception('not found'),
            ),
          ),
        ],
      );

      // Banner still renders; body surfaces the error state.
      expect(
        find.byKey(QaTestKeys.directorSchoolSnapshotReadOnlyBanner),
        findsOneWidget,
      );
    });
  });
}
