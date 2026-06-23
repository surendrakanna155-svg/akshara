import 'package:akshara_erp/features/student_app/exams/exam_models.dart';
import 'package:akshara_erp/features/student_app/exams/student_exams_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('studentExams providers', () {
    test('studentExamsProvider exposes upcoming without unpublished results', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(studentExamsFutureProvider.future);
      final data = container.read(studentExamsProvider);

      expect(data.upcomingExams, isNotEmpty);
      expect(data.examResults, isEmpty);
      expect(data.subjectScores, isEmpty);
      expect(data.averagePercent, 0);
    });

    test('studentExamSectionProvider switches section', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(studentExamSectionProvider.notifier).state =
          StudentExamSection.results;
      expect(
        container.read(studentExamSectionProvider),
        StudentExamSection.results,
      );
    });

    test('studentExamsEmptyProvider clears exam data', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(studentExamsEmptyProvider.notifier).state = true;
      final data = container.read(studentExamsProvider);

      expect(data.upcomingExams, isEmpty);
      expect(data.examResults, isEmpty);
    });
  });
}
