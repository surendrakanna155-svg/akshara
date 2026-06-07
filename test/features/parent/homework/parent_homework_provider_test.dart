import 'package:akshara_erp/features/parent/homework/homework_models.dart';
import 'package:akshara_erp/features/parent/homework/parent_homework_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('parentHomework providers', () {
    test('parentHomeworkDataProvider exposes mock child context', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentHomeworkFutureProvider.future);
      final data = container.read(parentHomeworkDataProvider);

      expect(data.childName, 'Ravi Kumar');
      expect(data.childClass, '8-A');
      expect(data.items, isNotEmpty);
    });

    test('homeworkFilterProvider filters pending items', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentHomeworkFutureProvider.future);
      container.read(homeworkFilterProvider.notifier).state =
          HomeworkFilter.pending;
      final items = container.read(parentHomeworkItemsProvider);

      expect(items, isNotEmpty);
      expect(
        items.every((item) => item.status == ParentHomeworkStatus.pending),
        isTrue,
      );
    });

    test('homeworkFilterProvider filters overdue items', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentHomeworkFutureProvider.future);
      container.read(homeworkFilterProvider.notifier).state =
          HomeworkFilter.overdue;
      final items = container.read(parentHomeworkItemsProvider);

      expect(items, isNotEmpty);
      expect(
        items.every((item) => item.status == ParentHomeworkStatus.overdue),
        isTrue,
      );
    });

    test('parentHomeworkEmptyProvider clears homework list', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(parentHomeworkEmptyProvider.notifier).state = true;
      final items = container.read(parentHomeworkItemsProvider);

      expect(items, isEmpty);
    });
  });
}
