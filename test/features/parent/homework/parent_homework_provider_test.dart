import 'package:akshara_erp/features/parent/homework/homework_models.dart';
import 'package:akshara_erp/features/parent/homework/parent_homework_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parentHomework providers', () {
    test('parentHomeworkDataProvider exposes mock child context', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(parentHomeworkDataProvider);

      expect(data.childName, 'Ravi Kumar');
      expect(data.childClass, '8-A');
      expect(data.items, isNotEmpty);
    });

    test('homeworkFilterProvider filters pending items', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(homeworkFilterProvider.notifier).state =
          HomeworkFilter.pending;
      final items = container.read(parentHomeworkItemsProvider);

      expect(items, isNotEmpty);
      expect(
        items.every((item) => item.status == ParentHomeworkStatus.pending),
        isTrue,
      );
    });

    test('homeworkFilterProvider filters overdue items', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(homeworkFilterProvider.notifier).state =
          HomeworkFilter.overdue;
      final items = container.read(parentHomeworkItemsProvider);

      expect(items, isNotEmpty);
      expect(
        items.every((item) => item.status == ParentHomeworkStatus.overdue),
        isTrue,
      );
    });

    test('parentHomeworkEmptyProvider clears homework list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(parentHomeworkEmptyProvider.notifier).state = true;
      final items = container.read(parentHomeworkItemsProvider);

      expect(items, isEmpty);
    });
  });
}
