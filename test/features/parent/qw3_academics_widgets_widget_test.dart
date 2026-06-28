import 'package:akshara_erp/features/parent/academics/widgets/academics_shortcuts_strip.dart';
import 'package:akshara_erp/features/parent/exams/exam_models.dart';
import 'package:akshara_erp/features/parent/exams/widgets/exam_result_row.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW3 · QA-F-013 (parent exam result row) and
/// QA-F-015 (academics shortcuts strip). Both widgets were never pumped —
/// covered here for render + tap-callback wiring.
Future<void> _pump(WidgetTester tester, Widget child) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QA-F-013 · ExamResultRow', () {
    testWidgets('renders subject, term, score and grade', (tester) async {
      await _pump(
        tester,
        const ExamResultRow(
          item: ExamResultItem(
            id: 'res_1',
            title: 'Mathematics',
            termLabel: 'Term 1',
            dateLabel: '18 Apr 2026',
            scoreObtained: 86,
            maxScore: 100,
            grade: 'A',
            remarks: 'Strong problem solving.',
          ),
        ),
      );

      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.textContaining('Term 1'), findsOneWidget);
      expect(find.text('86/100'), findsOneWidget);
      // percent (86) + grade rendered together.
      expect(find.text('86% · A'), findsOneWidget);
      expect(find.text('Strong problem solving.'), findsOneWidget);
    });

    testWidgets('fires the onTap callback', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        ExamResultRow(
          item: const ExamResultItem(
            id: 'res_2',
            title: 'Science',
            termLabel: 'Term 1',
            dateLabel: '20 Apr 2026',
            scoreObtained: 79,
            maxScore: 100,
            grade: 'B+',
          ),
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.text('Science'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('QA-F-015 · AcademicsShortcutsStrip', () {
    testWidgets('renders the three shortcut tiles', (tester) async {
      await _pump(tester, const AcademicsShortcutsStrip());

      expect(find.text('Academics'), findsOneWidget);
      expect(find.text('Timetable'), findsOneWidget);
      expect(find.text('Homework'), findsOneWidget);
      expect(find.text('Exams'), findsOneWidget);
    });

    testWidgets('fires each tile navigation callback', (tester) async {
      var timetable = false;
      var homework = false;
      var exams = false;
      await _pump(
        tester,
        AcademicsShortcutsStrip(
          onTimetableTap: () => timetable = true,
          onHomeworkTap: () => homework = true,
          onExamsTap: () => exams = true,
        ),
      );

      await tester.tap(find.text('Timetable'));
      await tester.pump();
      await tester.tap(find.text('Homework'));
      await tester.pump();
      await tester.tap(find.text('Exams'));
      await tester.pump();

      expect(timetable, isTrue);
      expect(homework, isTrue);
      expect(exams, isTrue);
    });
  });
}
