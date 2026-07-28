import 'package:akshara_erp/core/exams/exam_grading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExamGradingScale.standard (must match legacy fixed scale)', () {
    const scale = ExamGradingScale.standard;

    test('boundaries map to the same grades as the old _gradeForPercent', () {
      expect(scale.gradeFor(100), 'A+');
      expect(scale.gradeFor(90), 'A+');
      expect(scale.gradeFor(89.9), 'A');
      expect(scale.gradeFor(80), 'A');
      expect(scale.gradeFor(70), 'B+');
      expect(scale.gradeFor(60), 'B');
      expect(scale.gradeFor(50), 'C');
      expect(scale.gradeFor(49.9), 'D');
      expect(scale.gradeFor(0), 'D');
    });
  });

  group('board presets', () {
    test('CBSE scale awards expected bands', () {
      const cbse = ExamGradingScale.cbseScholastic;
      expect(cbse.gradeFor(95), 'A1');
      expect(cbse.gradeFor(85), 'A2');
      expect(cbse.gradeFor(40), 'D');
      expect(cbse.gradeFor(20), 'E');
    });

    test('percentage/division scale awards expected bands', () {
      const div = ExamGradingScale.percentageDivision;
      expect(div.gradeFor(80), 'Distinction');
      expect(div.gradeFor(65), 'First');
      expect(div.gradeFor(52), 'Second');
      expect(div.gradeFor(36), 'Third');
      expect(div.gradeFor(30), 'Fail');
    });

    test('State Board SSC scale awards expected bands', () {
      const ssc = ExamGradingScale.stateBoardSsc;
      expect(ssc.gradeFor(95), 'A1');
      expect(ssc.gradeFor(85), 'A2');
      expect(ssc.gradeFor(76), 'B1');
      expect(ssc.gradeFor(68), 'B2');
      expect(ssc.gradeFor(60), 'C1');
      expect(ssc.gradeFor(52), 'C2');
      expect(ssc.gradeFor(40), 'D');
      expect(ssc.gradeFor(30), 'E');
    });

    test('State Board and CBSE are NOT interchangeable at the boundaries', () {
      // The two ladders share labels but not thresholds. A State-Board school
      // publishing on the CBSE preset would print the wrong grade on real
      // report cards, which is why they are separate presets.
      const ssc = ExamGradingScale.stateBoardSsc;
      const cbse = ExamGradingScale.cbseScholastic;
      expect(cbse.gradeFor(91), 'A1');
      expect(ssc.gradeFor(91), 'A2'); // State Board A1 starts at 92
      expect(cbse.gradeFor(75), 'B1');
      expect(ssc.gradeFor(75), 'B1');
      expect(cbse.gradeFor(72), 'B1');
      expect(ssc.gradeFor(72), 'B2'); // State Board B1 starts at 75
    });

    test('four presets are available to choose from', () {
      expect(ExamGradingScale.presets, hasLength(4));
      expect(
        ExamGradingScale.presets.map((s) => s.name),
        containsAll(<String>[
          'Standard',
          'CBSE (A1–E)',
          'State Board — SSC (A1–E)',
          'Percentage / Division',
        ]),
      );
    });
  });

  group('ExamReportSettings', () {
    test('default = standard scale, rank hidden', () {
      final settings = ExamReportSettings.standard();
      expect(settings.gradingScale.name, 'Standard');
      expect(settings.showRankToParents, isFalse);
      expect(settings.suggestedTerms, isEmpty);
    });

    test('copyWith toggles rank visibility and swaps scale', () {
      final settings = ExamReportSettings.standard().copyWith(
        gradingScale: ExamGradingScale.cbseScholastic,
        showRankToParents: true,
        suggestedTerms: const ['Unit Test 1', 'Half-Yearly', 'Annual'],
      );
      expect(settings.gradingScale.name, 'CBSE (A1–E)');
      expect(settings.showRankToParents, isTrue);
      expect(settings.suggestedTerms, hasLength(3));
    });
  });
}
