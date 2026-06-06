import 'package:akshara_erp/features/student/timetable/student_timetable_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('studentTimetable providers', () {
    test('studentTimetableProvider exposes weekly schedule', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(studentTimetableProvider);

      expect(data.childName, 'Ravi Kumar');
      expect(data.days, isNotEmpty);
      expect(data.selectedDay?.periods, isNotEmpty);
    });

    test('studentTimetableSelectedDayProvider switches day', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(studentTimetableSelectedDayProvider.notifier).state = 'mon';
      final data = container.read(studentTimetableProvider);

      expect(data.selectedDay?.id, 'mon');
    });

    test('studentTimetableEmptyProvider clears schedule', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(studentTimetableEmptyProvider.notifier).state = true;
      final data = container.read(studentTimetableProvider);

      expect(data.days, isEmpty);
    });
  });
}
