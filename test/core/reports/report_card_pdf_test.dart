import 'package:akshara_erp/core/exams/exam_remark.dart';
import 'package:akshara_erp/core/exams/exam_report_card.dart';
import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/features/parent/receipts/receipt_models.dart';
import 'package:flutter_test/flutter_test.dart';

ExamReportCard sampleCard({
  bool rankShown = true,
  String? remark = 'Strong improvement this term.',
  String? leadershipRemark = 'Commended by the principal.',
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
      remarkAuthorRole:
          remark == null ? null : ExamRemarkAuthorRole.classTeacher,
      leadershipRemark: leadershipRemark,
      leadershipRemarkAuthorName:
          leadershipRemark == null ? null : 'Anand Rao',
      leadershipRemarkAuthorRole:
          leadershipRemark == null ? null : ExamRemarkAuthorRole.principal,
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
      card: sampleCard(rankShown: false, remark: null, leadershipRemark: null),
      schoolName: 'Akshara Vidyalaya',
    );
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('buildReceiptPdf produces a valid PDF', () async {
    const receipt = FeeReceipt(
      id: 'rcpt_term_2',
      receiptNumber: 'APS-2026-TERM_2',
      title: 'Term 2 — Fee payment',
      dateLabel: 'Just now',
      amount: 4200,
      paymentMethod: 'UPI',
      statusLabel: 'Paid',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      category: 'Tuition',
      lineItems: [ReceiptLineItem(label: 'Term 2', amount: 4200)],
      schoolName: 'Akshara Vidyalaya',
    );
    final bytes = await service.buildReceiptPdf(receipt: receipt);
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
