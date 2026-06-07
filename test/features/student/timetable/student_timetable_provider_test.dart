import 'package:akshara_erp/features/student/timetable/student_timetable_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('studentTimetable providers', () {
    test('studentTimetableProvider exposes weekly schedule', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(studentTimetableFutureProvider.future);
      final data = container.read(studentTimetableProvider);

      expect(data.childName, 'Ravi Kumar');
      expect(data.days, isNotEmpty);
      expect(data.selectedDay?.periods, isNotEmpty);
    });

    test('studentTimetableSelectedDayProvider switches day', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(studentTimetableFutureProvider.future);
      container.read(studentTimetableSelectedDayProvider.notifier).state = 'mon';
      final data = container.read(studentTimetableProvider);

      expect(data.selectedDay?.id, 'mon');
    });

    test('studentTimetableEmptyProvider clears schedule', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(studentTimetableEmptyProvider.notifier).state = true;
      final data = container.read(studentTimetableProvider);

      expect(data.days, isEmpty);
    });
  });
}
