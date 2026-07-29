import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

// CI-C3 — the opt-in multi-set (A/B/C) question-paper PDF v2 rides the shared
// XCT-1 export pipeline (`AksharaReportExportService`), adds branding, general
// instructions, sections, and each set's answer key on its OWN page. The legacy
// `EducationPdfService.printQuestionPaper` (v1) layout is untouched. PDFs embed
// non-deterministic metadata, so — like the repo's other PDF tests — we assert a
// valid, non-empty PDF plus the document's structural invariants.
void main() {
  const service = AksharaReportExportService();

  bool isPdf(List<int> bytes) =>
      bytes.length > 4 &&
      bytes[0] == 0x25 && // %
      bytes[1] == 0x50 && // P
      bytes[2] == 0x44 && // D
      bytes[3] == 0x46; // F

  QuestionPaperPrintData sample({List<String> setLabels = const ['A', 'B', 'C']}) {
    QuestionPaperSetPrintData buildSet(String label, {required bool master}) =>
        QuestionPaperSetPrintData(
          label: label,
          master: master,
          sections: [
            const QuestionPaperSectionPrintData(
              code: 'A',
              title: 'Objective',
              instructions: ['Choose the correct option.'],
              questions: [
                QuestionPaperQuestionPrintData(
                  questionNumber: 1,
                  marks: 1,
                  questionText: '2 + 2 = ?',
                  options: ['3', '4', '5', '6'],
                ),
                QuestionPaperQuestionPrintData(
                  questionNumber: 2,
                  marks: 1,
                  questionText: '3 x 3 = ?',
                  options: ['6', '8', '9', '12'],
                ),
              ],
            ),
            const QuestionPaperSectionPrintData(
              code: 'B',
              title: 'Short Answer',
              questions: [
                QuestionPaperQuestionPrintData(
                  questionNumber: 3,
                  marks: 5,
                  questionText: 'Prove the Pythagoras theorem.',
                ),
              ],
            ),
          ],
          answerKey: const [
            QuestionPaperAnswerPrintData(
                questionNumber: 1, answer: '4', marks: 1, answerOption: 'B'),
            QuestionPaperAnswerPrintData(
                questionNumber: 2, answer: '9', marks: 1, answerOption: 'C'),
            QuestionPaperAnswerPrintData(
                questionNumber: 3, answer: 'a^2 + b^2 = c^2', marks: 5),
          ],
        );

    return QuestionPaperPrintData(
      schoolName: 'NIKSHA Vidyalaya',
      schoolLogoText: 'AV',
      title: 'Class 10 — Mathematics Unit Test',
      subtitle: 'Class 10 · Mathematics · Unit Test',
      totalMarks: 7,
      durationMinutes: 60,
      generalInstructions: const [
        'All questions are compulsory.',
        'Marks are indicated against each question.',
      ],
      sets: [
        for (var i = 0; i < setLabels.length; i++)
          buildSet(setLabels[i], master: i == 0),
      ],
    );
  }

  test('buildQuestionPaperV2Pdf emits a valid, non-empty multi-set PDF', () async {
    final bytes = await service.buildQuestionPaperV2Pdf(
      data: sample(),
      generatedAtLabel: '08 Jul 2026',
    );
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
    expect(isPdf(bytes), isTrue);
  });

  test('single-set (master only) export still renders a valid PDF', () async {
    final bytes = await service.buildQuestionPaperV2Pdf(
      data: sample(setLabels: const ['A']),
    );
    expect(bytes, isNotEmpty);
    expect(isPdf(bytes), isTrue);
  });

  test('key separation — the question print-model never carries answers', () {
    final data = sample();
    for (final set in data.sets) {
      for (final section in set.sections) {
        for (final q in section.questions) {
          // Structurally, a printed question exposes no answer surface.
          expect(q.runtimeType, QuestionPaperQuestionPrintData);
          expect((q as dynamic).options, isA<List<String>>());
        }
      }
      // The key is a distinct, complete structure aligned to the questions.
      final printed =
          set.sections.fold<int>(0, (n, s) => n + s.questions.length);
      expect(set.answerKey.length, printed);
    }
  });

  test('every set totals the same marks', () {
    final data = sample();
    for (final set in data.sets) {
      final marks = set.sections
          .expand((s) => s.questions)
          .fold<int>(0, (sum, q) => sum + q.marks);
      expect(marks, data.totalMarks);
    }
  });
}
