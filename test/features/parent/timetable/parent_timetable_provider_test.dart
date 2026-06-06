import 'package:akshara_erp/features/parent/timetable/parent_timetable_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parentTimetableProvider', () {
    test('returns mock week data for Ravi Kumar', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(parentTimetableProvider);

      expect(data.childName, 'Ravi Kumar');
      expect(data.childClass, '8-A');
      expect(data.days, isNotEmpty);
      expect(data.totalPeriodsThisWeek, greaterThan(0));
    });

    test('reflects selected day from parentTimetableSelectedDayProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(parentTimetableSelectedDayProvider.notifier).state = 'mon';
      final monday = container.read(parentTimetableProvider).selectedDay;

      expect(monday, isNotNull);
      expect(monday!.id, 'mon');
      expect(monday.shortLabel, 'Mon');
      expect(monday.periods, isNotEmpty);
    });

    test('returns empty payload when parentTimetableEmptyProvider is true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(parentTimetableEmptyProvider.notifier).state = true;
      final data = container.read(parentTimetableProvider);

      expect(data.days, isEmpty);
      expect(data.totalPeriodsThisWeek, 0);
    });
  });
}
