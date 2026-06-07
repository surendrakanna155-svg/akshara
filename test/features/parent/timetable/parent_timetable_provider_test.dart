import 'package:akshara_erp/features/parent/timetable/parent_timetable_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('parentTimetableProvider', () {
    test('returns mock week data for Ravi Kumar', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentTimetableFutureProvider.future);
      final data = container.read(parentTimetableProvider);

      expect(data.childName, 'Ravi Kumar');
      expect(data.childClass, '8-A');
      expect(data.days, isNotEmpty);
      expect(data.totalPeriodsThisWeek, greaterThan(0));
    });

    test('reflects selected day from parentTimetableSelectedDayProvider', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentTimetableFutureProvider.future);
      container.read(parentTimetableSelectedDayProvider.notifier).state = 'mon';
      final monday = container.read(parentTimetableProvider).selectedDay;

      expect(monday, isNotNull);
      expect(monday!.id, 'mon');
      expect(monday.shortLabel, 'Mon');
      expect(monday.periods, isNotEmpty);
    });

    test('returns empty payload when parentTimetableEmptyProvider is true', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(parentTimetableEmptyProvider.notifier).state = true;
      final data = container.read(parentTimetableProvider);

      expect(data.days, isEmpty);
      expect(data.totalPeriodsThisWeek, 0);
    });
  });
}
