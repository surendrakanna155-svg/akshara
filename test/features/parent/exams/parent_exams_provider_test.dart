import 'package:akshara_erp/features/parent/exams/exam_models.dart';
import 'package:akshara_erp/features/parent/exams/parent_exams_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('parentExamsProvider', () {
    test('returns exams from administration store without published results', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentExamsFutureProvider.future);
      final data = container.read(parentExamsProvider);

      expect(data.childName, 'Ravi Kumar');
      expect(data.childClass, '8-A');
      expect(data.upcomingExams, isNotEmpty);
      expect(data.examResults, isEmpty);
    });

    test('parentExamSectionProvider defaults to upcoming', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      expect(
        container.read(parentExamSectionProvider),
        ExamSection.upcoming,
      );
    });

    test('parentExamsEmptyProvider clears both sections', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(parentExamsEmptyProvider.notifier).state = true;
      final data = container.read(parentExamsProvider);

      expect(data.upcomingExams, isEmpty);
      expect(data.examResults, isEmpty);
    });
  });
}
