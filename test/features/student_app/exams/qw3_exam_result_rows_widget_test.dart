import 'package:akshara_erp/features/student_app/exams/exam_models.dart';
import 'package:akshara_erp/features/student_app/exams/widgets/exam_result_row.dart';
import 'package:akshara_erp/features/student_app/exams/widgets/subject_score_row.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// QW3 · QA-F-043 — Student exam result row + subject score row render.
/// `exam_result_row.dart` and `subject_score_row.dart` (ST-05) were never
/// pumped. These are pure stateless rows: pump with sample models and assert
/// the title / marks / percent / grade render.

const _result = StudentExamResult(
  id: 'res-1',
  title: 'Mid-Term Examination',
  termLabel: 'Term 1',
  dateLabel: '12 May 2026',
  scoreObtained: 78,
  maxScore: 100,
  grade: 'A',
);

const _score = SubjectScore(
  subject: 'Mathematics',
  scorePercent: 82,
  grade: 'A',
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

void main() {
  group('QA-F-043 · ExamResultRow', () {
    testWidgets('renders title, term/date, marks and grade', (tester) async {
      await _pump(tester, const ExamResultRow(result: _result));

      expect(find.text('Mid-Term Examination'), findsOneWidget);
      expect(find.text('Term 1 · 12 May 2026'), findsOneWidget);
      // scoreObtained / maxScore and the letter grade.
      expect(find.text('78/100'), findsOneWidget);
      expect(find.text('Grade A'), findsOneWidget);
    });
  });

  group('QA-F-043 · SubjectScoreRow', () {
    testWidgets('renders subject, percent and grade chip', (tester) async {
      await _pump(tester, const SubjectScoreRow(score: _score));

      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('renders a distinct grade for a different score',
        (tester) async {
      await _pump(
        tester,
        const SubjectScoreRow(
          score: SubjectScore(subject: 'Science', scorePercent: 64, grade: 'B'),
        ),
      );

      expect(find.text('Science'), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });
  });
}
