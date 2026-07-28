import 'package:akshara_erp/features/student_app/exams/exam_models.dart';
import 'package:akshara_erp/features/student_app/exams/student_exams_provider.dart';
import 'package:akshara_erp/features/student_app/progress/student_progress_screen.dart';
import 'package:akshara_erp/shared/widgets/widgets.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// RC honest-state certification for ST-07 (`StudentProgressScreen`).
///
/// The standing rule: the UI never presents an unknown value as a measured one.
/// `weakSubjects.isEmpty` used to be true both for "every subject is strong"
/// AND for "nothing has ever been measured", so a brand-new student with zero
/// published marks was congratulated on performance that was never measured.
/// These tests pin the measured/unmeasured distinction, plus the loading and
/// error paths the screen previously ignored entirely.
const _praise = 'Strong performance across subjects — keep your revision '
    'streak.';

StudentExamsData _data({List<SubjectScore> scores = const []}) =>
    StudentExamsData(
      studentName: 'Ravi Kumar',
      classLabel: '8-A',
      upcomingExams: const [],
      examResults: const [],
      subjectScores: scores,
      averagePercent: 0,
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
        home: const StudentProgressScreen(),
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
  group('ST-07 progress — honest state', () {
    testWidgets(
        'a student with NO published subject scores is not praised and is not '
        'shown an empty "Subject progress" section', (tester) async {
      await _pump(
        tester,
        overrides: [studentExamsProvider.overrideWithValue(_data())],
      );

      // No praise for performance that was never measured.
      expect(find.text(_praise), findsNothing);
      expect(find.textContaining('Strong performance'), findsNothing);

      // The heading is still there, but it is followed by an honest empty
      // state rather than dead space.
      expect(find.text('Subject progress'), findsOneWidget);
      expect(find.byType(AksharaSectionEmpty), findsNWidgets(2));
      expect(
        find.textContaining('No subject scores published yet'),
        findsWidgets,
      );
      expect(find.byType(AksharaInsightCard), findsNothing);
    });

    testWidgets('a student whose measured scores are all strong IS praised',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          studentExamsProvider.overrideWithValue(
            _data(
              scores: const [
                SubjectScore(subject: 'Mathematics', scorePercent: 88,
                    grade: 'A'),
                SubjectScore(subject: 'Science', scorePercent: 91, grade: 'A+'),
              ],
            ),
          ),
        ],
      );

      expect(find.byType(AksharaInsightCard), findsOneWidget);
      expect(find.textContaining('Strong performance'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
    });

    testWidgets('a student with a weak measured subject gets focus guidance',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          studentExamsProvider.overrideWithValue(
            _data(
              scores: const [
                SubjectScore(subject: 'Mathematics', scorePercent: 51,
                    grade: 'C'),
                SubjectScore(subject: 'Science', scorePercent: 91, grade: 'A+'),
              ],
            ),
          ),
        ],
      );

      expect(find.textContaining('Focus revision on Mathematics'),
          findsOneWidget);
      expect(find.textContaining('Strong performance'), findsNothing);
    });

    testWidgets('shows the loading state instead of a blank progress screen',
        (tester) async {
      await _pump(
        tester,
        overrides: [studentExamsLoadingProvider.overrideWith((ref) => true)],
        settle: false,
      );

      expect(find.byType(AksharaLoadingState), findsOneWidget);
      expect(find.text('Subject progress'), findsNothing);
      expect(find.textContaining('Strong performance'), findsNothing);
    });

    testWidgets('a FAILED fetch shows the error state, not a blank screen',
        (tester) async {
      await _pump(
        tester,
        overrides: [
          studentExamsFutureProvider.overrideWith(
            (ref) async => throw Exception('network down'),
          ),
        ],
      );

      expect(find.byType(AksharaErrorState), findsOneWidget);
      expect(find.text('Unable to load progress right now.'), findsOneWidget);
      expect(find.text('Subject progress'), findsNothing);
      expect(find.textContaining('Strong performance'), findsNothing);
    });
  });
}
