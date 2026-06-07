import 'package:akshara_erp/features/student/homework/homework_models.dart';
import 'package:akshara_erp/features/student/homework/student_homework_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('studentHomework providers', () {
    test('studentHomeworkProvider exposes mock items', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(studentHomeworkProvider);

      expect(data.studentName, 'Ravi Kumar');
      expect(data.items, isNotEmpty);
      expect(data.pendingCount, greaterThan(0));
    });

    test('studentHomeworkFilterProvider filters pending homework', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(studentHomeworkFilterProvider.notifier).state =
          StudentHomeworkFilter.pending;
      final items = container.read(studentHomeworkItemsProvider);

      expect(items, isNotEmpty);
      expect(
        items.every(
          (i) =>
              i.status == StudentHomeworkStatus.pending ||
              i.status == StudentHomeworkStatus.overdue,
        ),
        isTrue,
      );
    });

    test('studentHomeworkEmptyProvider clears list', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(studentHomeworkEmptyProvider.notifier).state = true;
      expect(container.read(studentHomeworkItemsProvider), isEmpty);
    });
  });
}
