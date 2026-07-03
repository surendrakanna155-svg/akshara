import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/academics/timetable/timetable_hub_screen.dart';
import 'package:akshara_erp/features/academics/timetable/timetable_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Roadmap gap #9 — the workload dashboard is a pure widget over a
/// [WorkloadRollup], so we can render it directly (no hub shell / router).
const _rollup = WorkloadRollup(
  teachers: [
    TeacherWorkloadRollup(
      teacherId: 'T-OVER',
      teacherName: 'Aisha Khan',
      periodCount: 28,
      sections: ['8-A', '8-B'],
      subjectIds: ['Mathematics', 'Science'],
      status: TeacherWorkloadStatus.over,
      isOverloaded: true,
    ),
    TeacherWorkloadRollup(
      teacherId: 'T-BAL',
      teacherName: 'Ravi Menon',
      periodCount: 18,
      sections: ['9-A'],
      subjectIds: ['English'],
      status: TeacherWorkloadStatus.balanced,
      isOverloaded: false,
    ),
    TeacherWorkloadRollup(
      teacherId: 'T-UNDER',
      teacherName: 'Sara Iyer',
      periodCount: 6,
      sections: ['7-C'],
      subjectIds: ['Activity'],
      status: TeacherWorkloadStatus.under,
      isOverloaded: false,
    ),
  ],
  summary: WorkloadRollupSummary(
    totalTeachers: 3,
    overloaded: 1,
    underloaded: 1,
    balanced: 1,
    avgPeriods: 17.33,
  ),
);

Widget _host(Widget child) => MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(body: child),
    );

/// The accent colour actually used for a status chip/bar in the rendered tree.
Color _statusColor(WidgetTester tester, TeacherWorkloadStatus status) {
  final ctx = tester.element(find.byType(TimetableWorkloadDashboard));
  return switch (status) {
    TeacherWorkloadStatus.over => ctx.colors.error,
    TeacherWorkloadStatus.under => ctx.akshara.warning,
    TeacherWorkloadStatus.balanced => ctx.akshara.success,
  };
}

void main() {
  testWidgets('renders the summary header with all five aggregate stats',
      (tester) async {
    await tester.pumpWidget(_host(const TimetableWorkloadDashboard(rollup: _rollup)));
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.timetableWorkloadDashboard), findsOneWidget);
    expect(find.byKey(QaTestKeys.timetableWorkloadSummaryHeader), findsOneWidget);

    // total / over / under / balanced / avg periods.
    expect(find.text('Teachers'), findsOneWidget);
    expect(find.text('Overloaded'), findsWidgets); // header stat + status chip
    expect(find.text('Underloaded'), findsOneWidget);
    expect(find.text('Balanced'), findsWidgets); // header stat + status chip
    expect(find.text('Avg periods'), findsOneWidget);
    expect(find.text('17.3'), findsOneWidget); // fractional avg formatted
  });

  testWidgets('renders one row per teacher with section + subject chips',
      (tester) async {
    await tester.pumpWidget(_host(const TimetableWorkloadDashboard(rollup: _rollup)));
    await tester.pumpAndSettle();

    for (final id in ['T-OVER', 'T-BAL', 'T-UNDER']) {
      expect(find.byKey(QaTestKeys.timetableWorkloadRow(id)), findsOneWidget);
    }

    // Names, not UUIDs.
    expect(find.text('Aisha Khan'), findsOneWidget);
    expect(find.text('28 periods / week'), findsOneWidget);

    // Section chips.
    expect(find.text('8-A'), findsOneWidget);
    expect(find.text('8-B'), findsOneWidget);
    // Subject chips.
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Science'), findsOneWidget);
  });

  testWidgets('status chips are colour-coded over=red / under=amber / balanced=green',
      (tester) async {
    await tester.pumpWidget(_host(const TimetableWorkloadDashboard(rollup: _rollup)));
    await tester.pumpAndSettle();

    Chip chipIn(String teacherId, String label) {
      final row = find.byKey(QaTestKeys.timetableWorkloadRow(teacherId));
      return tester.widget<Chip>(
        find.descendant(of: row, matching: find.widgetWithText(Chip, label)),
      );
    }

    final overChip = chipIn('T-OVER', 'Overloaded');
    final underChip = chipIn('T-UNDER', 'Under-utilised');
    final balChip = chipIn('T-BAL', 'Balanced');

    expect(
      (overChip.side as BorderSide).color,
      _statusColor(tester, TeacherWorkloadStatus.over),
    );
    expect(
      (underChip.side as BorderSide).color,
      _statusColor(tester, TeacherWorkloadStatus.under),
    );
    expect(
      (balChip.side as BorderSide).color,
      _statusColor(tester, TeacherWorkloadStatus.balanced),
    );
  });

  testWidgets('honest empty state when there is no timetable/workload',
      (tester) async {
    await tester.pumpWidget(
      _host(const TimetableWorkloadDashboard(rollup: WorkloadRollup.empty)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.timetableWorkloadEmptyState), findsOneWidget);
    expect(find.byKey(QaTestKeys.timetableWorkloadDashboard), findsNothing);
    expect(
      find.text('Generate and publish a timetable to see per-teacher workload.'),
      findsOneWidget,
    );
  });

  testWidgets('export button fires the provided callback', (tester) async {
    var exported = false;
    await tester.pumpWidget(
      _host(TimetableWorkloadDashboard(
        rollup: _rollup,
        onExport: () => exported = true,
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(QaTestKeys.timetableWorkloadExportButton));
    await tester.pump();
    expect(exported, isTrue);
  });
}
