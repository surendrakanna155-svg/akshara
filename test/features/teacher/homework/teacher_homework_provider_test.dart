import 'package:akshara_erp/features/teacher/homework/homework_models.dart';
import 'package:akshara_erp/features/teacher/homework/teacher_homework_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('teacherHomework providers', () {
    test('teacherHomeworkAssignmentsProvider exposes mock assignments', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(teacherHomeworkFutureProvider.future);
      final assignments = container.read(teacherHomeworkAssignmentsProvider);

      expect(assignments, hasLength(2));
      expect(assignments.first.classLabel, '8-A');
      expect(assignments.first.pendingCount, greaterThan(0));
    });

    test('teacherHomeworkProvider tracks selected assignment', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(teacherHomeworkFutureProvider.future);
      container.read(teacherHomeworkAssignmentProvider.notifier).state =
          'hw_9b_1';
      final selected = container.read(teacherHomeworkProvider);

      expect(selected?.id, 'hw_9b_1');
      expect(selected?.classLabel, '9-B');
    });

    test('teacherHomeworkEmptyProvider clears assignments', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(teacherHomeworkEmptyProvider.notifier).state = true;
      final assignments = container.read(teacherHomeworkAssignmentsProvider);

      expect(assignments, isEmpty);
      expect(container.read(teacherHomeworkProvider), isNull);
    });

    test('assignments include pending and reviewed submissions', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(teacherHomeworkFutureProvider.future);
      final assignment = container.read(teacherHomeworkProvider)!;
      final statuses = assignment.submissions.map((s) => s.status).toSet();

      expect(statuses, contains(HomeworkReviewStatus.pending));
      expect(statuses, contains(HomeworkReviewStatus.reviewed));
    });
  });
}
