import 'package:akshara_erp/features/student/notices/notices_models.dart';
import 'package:akshara_erp/features/student/notices/student_notices_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('studentNotices providers', () {
    test('studentNoticesProvider exposes school and class notices', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(studentNoticesProvider);

      expect(data.notices, hasLength(4));
      expect(data.urgentCount, greaterThan(0));
    });

    test('studentNoticeScopeProvider filters school notices', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(studentNoticeScopeProvider.notifier).state =
          StudentNoticeScope.school;
      final items = container.read(studentNoticesItemsProvider);

      expect(items, isNotEmpty);
      expect(
        items.every((n) => n.scope == StudentNoticeScope.school),
        isTrue,
      );
    });

    test('studentNoticesEmptyProvider clears notices', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(studentNoticesEmptyProvider.notifier).state = true;
      expect(container.read(studentNoticesItemsProvider), isEmpty);
    });
  });
}
