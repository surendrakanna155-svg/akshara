import 'package:akshara_erp/features/student/exams/exam_models.dart';
import 'package:akshara_erp/features/student/exams/student_exams_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('studentExams providers', () {
    test('studentExamsProvider exposes upcoming and results', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(studentExamsProvider);

      expect(data.upcomingExams, isNotEmpty);
      expect(data.examResults, isNotEmpty);
      expect(data.subjectScores, hasLength(4));
      expect(data.averagePercent, greaterThan(0));
    });

    test('studentExamSectionProvider switches section', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(studentExamSectionProvider.notifier).state =
          StudentExamSection.results;
      expect(
        container.read(studentExamSectionProvider),
        StudentExamSection.results,
      );
    });

    test('studentExamsEmptyProvider clears exam data', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(studentExamsEmptyProvider.notifier).state = true;
      final data = container.read(studentExamsProvider);

      expect(data.upcomingExams, isEmpty);
      expect(data.examResults, isEmpty);
    });
  });
}
