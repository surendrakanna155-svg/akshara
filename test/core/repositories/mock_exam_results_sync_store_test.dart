import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    ExamAdministrationStore.instance.reset();
  });

  group('ExamAdministrationStore', () {
    test('publish stores result reachable by sisStudentId', () {
      final store = ExamAdministrationStore.instance..ensureSeeded();
      store.publishExamResults('exam_math_8a');

      final results = store.resultsForStudent('SIS-STU-10430');
      expect(results, isNotEmpty);
      expect(results.first.grade, isNotEmpty);
    });

    test('grade boundaries are correct', () {
      final store = ExamAdministrationStore.instance..ensureSeeded();
      store.recordMark(markEntryId: 'exam_math_8a_01', marksObtained: 45);
      store.publishExamResults('exam_math_8a');
      final result = store.resultForMarkEntry('exam_math_8a_01');
      expect(result?.grade, 'A+');
    });

    test('reset clears published results', () {
      final store = ExamAdministrationStore.instance..ensureSeeded();
      store.publishExamResults('exam_math_8a');
      store.reset();
      expect(store.hasPublishedResults, isFalse);
    });
  });
}
