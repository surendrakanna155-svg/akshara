import 'package:akshara_erp/core/exams/exam_report_card.dart';
import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/student_app/exams/exam_models.dart';
import 'package:akshara_erp/features/student_app/exams/report_card_provider.dart';
import 'package:akshara_erp/features/student_app/exams/student_exams_provider.dart';
import 'package:akshara_erp/features/student_app/progress/student_report_card_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

/// QW5 · QA-J-011 — Student · view report card / download results.
///
/// The student-side report card was display-only: the parent app could export
/// the PDF (`reportCardShareButton`) but the student app had no download action,
/// even though the shared [AksharaReportExportService.shareReportCardPdf] and the
/// student's own [studentReportCardProvider] already existed. QW5 wires the
/// student export action to that SAME shared service (parity with the parent
/// app — no new export pipeline). These tests prove the action appears only when
/// a published card exists and that tapping it dispatches the student's card to
/// the export service.
class _RecordingExportService extends AksharaReportExportService {
  _RecordingExportService(this.calls);

  final List<ExamReportCard> calls;

  @override
  Future<void> shareReportCardPdf({
    required ExamReportCard card,
    required String schoolName,
    String? generatedAtLabel,
  }) async {
    calls.add(card);
  }
}

const _examsData = StudentExamsData(
  studentName: 'Ravi Kumar',
  classLabel: '8-A',
  upcomingExams: [],
  examResults: [],
  subjectScores: [],
  averagePercent: 84,
  unreadNotifications: 0,
);

const _card = ExamReportCard(
  sisStudentId: 'SIS-STU-10430',
  studentName: 'Ravi Kumar',
  classLabel: '8-A',
  termLabel: 'Term 2',
  subjects: [
    ReportCardSubjectLine(
      subject: 'Mathematics',
      examTitle: 'Unit Test — Mathematics',
      score: 42,
      maxScore: 50,
      grade: 'A',
    ),
  ],
  totalScore: 42,
  totalMax: 50,
  overallGrade: 'A',
  rank: 2,
  classSize: 9,
  rankShown: false,
  attendancePercent: 92,
);

Future<List<ExamReportCard>> _pump(
  WidgetTester tester, {
  required ExamReportCard? card,
}) async {
  final calls = <ExamReportCard>[];
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        studentExamsProvider.overrideWithValue(_examsData),
        studentReportCardProvider.overrideWithValue(card),
        aksharaReportExportServiceProvider
            .overrideWithValue(_RecordingExportService(calls)),
      ]),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const StudentReportCardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  group('QW5 · QA-J-011 student report-card download', () {
    testWidgets('exposes the export action once a report card is published',
        (tester) async {
      await _pump(tester, card: _card);

      expect(
        find.byKey(QaTestKeys.studentReportCardExportButton),
        findsOneWidget,
      );
    });

    testWidgets('hides the export action when no card is published yet',
        (tester) async {
      await _pump(tester, card: null);

      expect(
        find.byKey(QaTestKeys.studentReportCardExportButton),
        findsNothing,
      );
    });

    testWidgets('tapping export dispatches the student card to the shared '
        'export service', (tester) async {
      final calls = await _pump(tester, card: _card);

      await tester.tap(find.byKey(QaTestKeys.studentReportCardExportButton));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.studentName, 'Ravi Kumar');
      expect(calls.single.termLabel, 'Term 2');
    });
  });
}
