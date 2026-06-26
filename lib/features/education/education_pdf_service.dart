import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'education_models.dart';

class EducationPdfService {
  static Future<void> printQuestionPaper(QuestionPaperDetail detail) async {
    // AI-1 moderation gate: only human-approved items may print onto the
    // student-facing paper — a rejected (disapproved) or still-pending AI
    // candidate must never reach the printed sheet. Renumber and rebuild the
    // answer key from the surviving items so the question numbers stay aligned.
    final printable =
        detail.items.where((item) => item.reviewStatus == 'approved').toList();
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(detail.paper.title)),
          pw.Text('Total marks: ${detail.paper.totalMarks}'),
          pw.SizedBox(height: 12),
          ...printable.asMap().entries.map(
            (entry) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    'Q${entry.key + 1}. (${entry.value.marks} marks) ${entry.value.questionText}'),
                if (entry.value.options.isNotEmpty)
                  ...entry.value.options.map((o) => pw.Text('  • $o')),
                pw.SizedBox(height: 8),
              ],
            ),
          ),
          pw.Divider(),
          pw.Header(level: 1, child: pw.Text('Answer Key')),
          ...printable.asMap().entries.map(
            (entry) => pw.Text(
              'Q${entry.key + 1}: ${entry.value.answerText ?? ''} (${entry.value.marks} marks)',
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  static Future<void> printHomework(HomeworkAssignment assignment) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(assignment.title)),
          pw.Text('${assignment.className} • ${assignment.subjectName} • ${assignment.topic}'),
          pw.SizedBox(height: 12),
          ...assignment.content.asMap().entries.map(
                (e) => pw.Text('${e.key + 1}. ${e.value['prompt'] ?? ''}'),
              ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  static Future<void> printReportCardRemark(ReportCardRemark remark) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Report Card Remark')),
          pw.Text('Student: ${remark.studentId}'),
          pw.Text('Year: ${remark.academicYearLabel}'),
          pw.Text('Type: ${remark.remarkType.name}'),
          pw.Text('Status: ${remark.status}'),
          pw.SizedBox(height: 12),
          pw.Text(remark.displayRemark),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}
