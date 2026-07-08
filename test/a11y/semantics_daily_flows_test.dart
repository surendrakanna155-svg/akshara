import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/attendance/widgets/attendance_exception_grid.dart';
import 'package:akshara_erp/shared/marks_grid/marks_grid.dart';
import 'package:akshara_erp/shared/widgets/akshara_kpi_card.dart';
import 'package:akshara_erp/shared/widgets/akshara_navigation.dart';
import 'package:akshara_erp/shared/widgets/akshara_quick_action_card.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// P2-UX-4 (Polish §7): "screen-reader pass over the five flows with Semantics
// labels verified — verify, don't assume." These pin the accessible names on
// the reused daily-flow interactive surfaces (previously the app-bar icon
// button had NO label when its tooltip path returned early).

Widget _app(Widget home) => MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(body: home),
    );

void main() {
  group('P2-UX-4 · screen-reader semantics on daily-flow surfaces', () {
    testWidgets('app-bar icon button announces its tooltip as a name',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        AksharaAppBarIconButton(
          icon: Icons.notifications_outlined,
          tooltip: 'Notifications',
          onPressed: () {},
        ),
      ));
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('app-bar icon button honours an explicit semanticLabel',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        AksharaAppBarIconButton(
          icon: Icons.search,
          tooltip: 'Search',
          semanticLabel: 'Search ERP',
          onPressed: () {},
        ),
      ));
      expect(find.bySemanticsLabel('Search ERP'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('attendance exception tile announces name, roll and mark',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        AttendanceExceptionGrid(
          students: const [
            TeacherAttendanceStudent(
              id: 's1',
              name: 'Asha',
              rollNo: '3',
              mark: StudentAttendanceMark.absent,
            ),
          ],
          enabled: true,
          onMark: (_, __) {},
        ),
      ));
      expect(
        find.bySemanticsLabel(RegExp(r'Asha.*roll 3.*Absent')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('marks column-stats announces progress', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        const MarksColumnStats(entered: 12, total: 30, averagePercent: 74),
      ));
      expect(find.bySemanticsLabel(RegExp('Marks progress')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('KPI card exposes a button role + label when tappable',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        SizedBox(
          width: 180,
          child: AksharaKpiCard(
            value: '94%',
            subtitle: 'Attendance',
            accent: KpiAccent.primary,
            semanticLabel: '94% attendance',
            onTap: () {},
          ),
        ),
      ));
      expect(find.bySemanticsLabel('94% attendance'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('quick-action card exposes a labelled button target',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        SizedBox(
          width: 160,
          child: AksharaQuickActionCard(
            icon: Icons.check_circle_outline,
            label: 'Mark attendance',
            onTap: () {},
          ),
        ),
      ));
      // The card nests an interactive surface, so the label surfaces on the
      // wrapper + the surface node — either announces it to a screen reader.
      expect(find.bySemanticsLabel('Mark attendance'), findsAtLeastNWidgets(1));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
