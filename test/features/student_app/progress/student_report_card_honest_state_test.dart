import 'package:akshara_erp/features/student_app/exams/exam_models.dart';
import 'package:akshara_erp/features/student_app/exams/student_exams_provider.dart';
import 'package:akshara_erp/features/student_app/progress/student_report_card_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// RC honest-state certification for ST-06 (`StudentReportCardScreen`).
///
/// `averagePercent` defaults to 0 in `studentExamsProvider`, so day one — and
/// on any network failure — the report card read "Average: 0.0%". Under the
/// standing honest-state rule an UNPUBLISHED average is UNKNOWN, not zero, so
/// it must not be rendered at all. These tests also pin the loading and error
/// paths the screen previously ignored entirely.
StudentExamsData _data({
  int averagePercent = 0,
  List<SubjectScore> scores = const [],
  List<StudentExamResult> results = const [],
}) =>
    StudentExamsData(
      studentName: 'Ravi Kumar',
      classLabel: '8-A',
      upcomingExams: const [],
      examResults: results,
      subjectScores: scores,
      averagePercent: averagePercent,
    );

const _result = StudentExamResult(
  id: 'r1',
  title: 'Unit Test — Mathematics',
  termLabel: 'Term 2',
  dateLabel: '12 Jun 2026',
  scoreObtained: 42,
  maxScore: 50,
  grade: 'A',
);

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
        home: const StudentReportCardScreen(),
      ),
    ),
  );
  if (settle) {
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  } else {
    // The loading state animates forever — pumpAndSettle would time out.
    await tester.pump();
  }
}

void main() {
  group('ST-06 report card — honest state', () {
    testWidgets(
        'a student with NO published results is never shown a measured average',
        (tester) async {
      await _pump(
        tester,
        overrides: [studentExamsProvider.overrideWithValue(_data())],
      );

      // The dishonest day-one reading.
      expect(find.text('Average: 0.0%'), findsNothing);
      expect(find.textContaining('Average:'), findsNothing);
      expect(find.text('Term summary'), findsNothing);
      expect(find.text('Subject scores'), findsNothing);
      expect(find.text('Recent results'), findsNothing);

      expect(find.byType(AksharaEmptyState), findsOneWidget);
      expect(
        find.textContaining('No exam results published yet'),
        findsOneWidget,
      );
    });

    testWidgets('a published average IS rendered as the measured value',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          studentExamsProvider.overrideWithValue(
            _data(
              averagePercent: 84,
              results: const [_result],
              scores: const [
                SubjectScore(subject: 'Mathematics', scorePercent: 84,
                    grade: 'A'),
              ],
            ),
          ),
        ],
      );

      expect(find.text('Term summary'), findsOneWidget);
      expect(find.text('Average: 84.0%'), findsOneWidget);
      expect(find.text('Subject scores'), findsOneWidget);
      expect(find.text('Recent results'), findsOneWidget);
      expect(find.byType(AksharaSectionEmpty), findsNothing);
    });

    testWidgets(
        'a partially published card guards each section header individually',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          studentExamsProvider.overrideWithValue(
            _data(
              averagePercent: 84,
              scores: const [
                SubjectScore(subject: 'Mathematics', scorePercent: 84,
                    grade: 'A'),
              ],
            ),
          ),
        ],
      );

      expect(find.text('Subject scores'), findsOneWidget);
      expect(find.text('Recent results'), findsOneWidget);
      // No exam-result rows → the "Recent results" heading gets an honest
      // empty state instead of dead space.
      expect(find.byType(AksharaSectionEmpty), findsOneWidget);
    });

    testWidgets('shows the loading state instead of a blank report card',
        (tester) async {
      await _pump(
        tester,
        overrides: [studentExamsLoadingProvider.overrideWith((ref) => true)],
        settle: false,
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
      expect(find.textContaining('Average:'), findsNothing);
    });

    testWidgets(
        'a FAILED fetch shows the error state, not a fully-populated-looking '
        'blank report card', (tester) async {
      await _pump(
        tester,
        overrides: [
          studentExamsFutureProvider.overrideWith(
            (ref) async => throw Exception('network down'),
          ),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(
        find.text('Unable to load your report card right now.'),
        findsOneWidget,
      );
      expect(find.textContaining('Average:'), findsNothing);
      expect(find.text('Term summary'), findsNothing);
    });
  });
}
