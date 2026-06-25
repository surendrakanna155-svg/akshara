import 'package:akshara_erp/core/exams/exam_remark.dart';
import 'package:akshara_erp/core/exams/exam_report_card.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/parent/exams/widgets/report_card_view.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ExamReportCard card({required bool rankShown}) => ExamReportCard(
      sisStudentId: 'SIS-STU-10430',
      studentName: 'Ravi Kumar',
      classLabel: '8-A',
      termLabel: 'Term 2',
      subjects: const [
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
      rankShown: rankShown,
      attendancePercent: 92,
    );

Widget host(ExamReportCard c) => MaterialApp(
      theme: AksharaAppTheme.light(),
      home: Scaffold(body: ReportCardView(card: c)),
    );

void main() {
  testWidgets('renders subjects and totals', (tester) async {
    await tester.pumpWidget(host(card(rankShown: false)));
    await tester.pumpAndSettle();

    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('8-A · Term 2'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('42/50'), findsWidgets); // subject + total
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('84%'), findsWidgets);
    expect(find.text('Attendance: 92%'), findsOneWidget);
  });

  testWidgets('hides rank when the school setting is off', (tester) async {
    await tester.pumpWidget(host(card(rankShown: false)));
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.reportCardRankChip), findsNothing);
  });

  testWidgets('shows rank when the school setting is on', (tester) async {
    await tester.pumpWidget(host(card(rankShown: true)));
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.reportCardRankChip), findsOneWidget);
    expect(find.text('Rank 2 of 9'), findsOneWidget);
  });

  testWidgets('renders class-teacher and principal remarks as distinct blocks',
      (tester) async {
    const c = ExamReportCard(
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
      remark: 'Strong improvement in algebra.',
      remarkAuthorName: 'Priya Sharma',
      remarkAuthorRole: ExamRemarkAuthorRole.classTeacher,
      leadershipRemark: 'Keep up the consistent effort.',
      leadershipRemarkAuthorName: 'Anand Rao',
      leadershipRemarkAuthorRole: ExamRemarkAuthorRole.principal,
    );

    await tester.pumpWidget(host(c));
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.reportCardRemark), findsOneWidget);
    expect(find.byKey(QaTestKeys.reportCardLeadershipRemark), findsOneWidget);
    expect(find.text('Class teacher remark'), findsOneWidget);
    expect(find.text("Principal's remark"), findsOneWidget);
    expect(find.text('Strong improvement in algebra.'), findsOneWidget);
    expect(find.text('Keep up the consistent effort.'), findsOneWidget);
    expect(find.text('— Priya Sharma'), findsOneWidget);
    expect(find.text('— Anand Rao'), findsOneWidget);
  });
}
