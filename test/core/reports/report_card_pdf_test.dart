import 'package:akshara_erp/core/exams/exam_report_card.dart';
import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

ExamReportCard sampleCard({
  bool rankShown = true,
  String? remark = 'Strong improvement this term.',
}) =>
    ExamReportCard(
      sisStudentId: 'SIS-STU-10430',
      studentName: 'Ravi Kumar',
      classLabel: '8-A',
      termLabel: 'Term 2',
      subjects: const [
        ReportCardSubjectLine(
          subject: 'Mathematics',
          examTitle: 'Unit Test',
          score: 42,
          maxScore: 50,
          grade: 'A',
        ),
        ReportCardSubjectLine(
          subject: 'Science',
          examTitle: 'Unit Test',
          score: 38,
          maxScore: 50,
          grade: 'B+',
        ),
      ],
      totalScore: 80,
      totalMax: 100,
      overallGrade: 'A',
      rank: 2,
      classSize: 9,
      rankShown: rankShown,
      attendancePercent: 92,
      remark: remark,
      remarkAuthorName: remark == null ? null : 'Priya Sharma',
    );

void main() {
  const service = AksharaReportExportService();

  test('buildReportCardPdf produces a non-empty PDF', () async {
    final bytes = await service.buildReportCardPdf(
      card: sampleCard(),
      schoolName: 'Akshara Vidyalaya',
      generatedAtLabel: '19 Jun 2026',
    );
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
    // PDF files start with the "%PDF" magic header.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('generates when rank is hidden and there is no remark', () async {
    final bytes = await service.buildReportCardPdf(
      card: sampleCard(rankShown: false, remark: null),
      schoolName: 'Akshara Vidyalaya',
    );
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
