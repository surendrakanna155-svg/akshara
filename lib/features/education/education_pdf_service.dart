import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'education_models.dart';

class EducationPdfService {
  static Future<void> printQuestionPaper(QuestionPaperDetail detail) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(detail.paper.title)),
          pw.Text('Total marks: ${detail.paper.totalMarks}'),
          pw.SizedBox(height: 12),
          ...detail.items.map(
            (item) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Q${item.questionNumber}. (${item.marks} marks) ${item.questionText}'),
                if (item.options.isNotEmpty)
                  ...item.options.map((o) => pw.Text('  • $o')),
                pw.SizedBox(height: 8),
              ],
            ),
          ),
          pw.Divider(),
          pw.Header(level: 1, child: pw.Text('Answer Key')),
          ...detail.answerKey.map(
            (entry) => pw.Text(
              'Q${entry['questionNumber']}: ${entry['answer']} (${entry['marks']} marks)',
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
}
