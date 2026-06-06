import 'package:akshara_erp/features/teacher/exams/exam_models.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('teacherExams providers', () {
    test('teacherExamsProvider exposes upcoming exams and marks', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(teacherExamsProvider);

      expect(data.upcomingExams, hasLength(2));
      expect(data.markEntries, isNotEmpty);
      expect(data.classAveragePercent, greaterThan(0));
    });

    test('teacherExamSectionProvider switches active section', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(teacherExamSectionProvider.notifier).state =
          TeacherExamSection.results;
      final section = container.read(teacherExamSectionProvider);

      expect(section, TeacherExamSection.results);
    });

    test('teacherExamsEmptyProvider clears exam data', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(teacherExamsEmptyProvider.notifier).state = true;
      final data = container.read(teacherExamsProvider);

      expect(data.upcomingExams, isEmpty);
      expect(data.markEntries, isEmpty);
      expect(data.classAveragePercent, 0);
    });

    test('mark entries include pending marks for entry', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final pending = container
          .read(teacherExamsProvider)
          .markEntries
          .where((entry) => entry.marksObtained == null);

      expect(pending, isNotEmpty);
    });
  });
}
