import 'package:akshara_erp/features/teacher/exams/exam_models.dart';
import 'package:akshara_erp/features/teacher/exams/teacher_exams_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

Future<void> _awaitTeacherExams(ProviderContainer container) async {
  await container.read(teacherUpcomingExamsFutureProvider.future);
  await container.read(teacherExamMarksFutureProvider.future);
}

void main() {
  group('teacherExams providers', () {
    test('teacherExamsProvider exposes upcoming exams and marks', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await _awaitTeacherExams(container);
      final data = container.read(teacherExamsProvider);

      expect(data.upcomingExams, hasLength(2));
      expect(data.markEntries, isNotEmpty);
      expect(data.classAveragePercent, greaterThan(0));
    });

    test('teacherExamSectionProvider switches active section', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(teacherExamSectionProvider.notifier).state =
          TeacherExamSection.results;
      final section = container.read(teacherExamSectionProvider);

      expect(section, TeacherExamSection.results);
    });

    test('teacherExamsEmptyProvider clears exam data', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(teacherExamsEmptyProvider.notifier).state = true;
      final data = container.read(teacherExamsProvider);

      expect(data.upcomingExams, isEmpty);
      expect(data.markEntries, isEmpty);
      expect(data.classAveragePercent, 0);
    });

    test('mark entries include pending marks for entry', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await _awaitTeacherExams(container);
      final pending = container
          .read(teacherExamsProvider)
          .markEntries
          .where((entry) => entry.marksObtained == null);

      expect(pending, isNotEmpty);
    });
  });
}
