import 'package:akshara_erp/features/parent/notices/notices_models.dart';
import 'package:akshara_erp/features/parent/notices/parent_notices_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('parentNoticesProvider', () {
    test('returns mock notices for active child', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentNoticesFutureProvider.future);
      final data = container.read(parentNoticesProvider);

      expect(data.childName, 'Ravi Kumar');
      expect(data.childClass, '8-A');
      expect(data.notices, isNotEmpty);
    });

    test('filters urgent notices', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentNoticesFutureProvider.future);
      container.read(parentNoticeCategoryProvider.notifier).state =
          NoticeCategory.urgent;
      final items = container.read(parentNoticesItemsProvider);

      expect(items, isNotEmpty);
      expect(items.every((item) => item.isUrgent), isTrue);
    });

    test('parentNoticesEmptyProvider clears list', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(parentNoticesEmptyProvider.notifier).state = true;
      final data = container.read(parentNoticesProvider);

      expect(data.notices, isEmpty);
    });
  });
}
