import 'package:akshara_erp/features/teacher/timetable/teacher_timetable_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('teacherTimetable providers', () {
    test('teacherTimetableProvider exposes weekly schedule', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(teacherTimetableProvider);

      expect(data.teacherName, 'Priya Sharma');
      expect(data.days, isNotEmpty);
      expect(data.selectedDay?.periods, isNotEmpty);
    });

    test('teacherTimetableDayProvider changes selected day', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(teacherTimetableDayProvider.notifier).state = 'mon';
      final data = container.read(teacherTimetableProvider);

      expect(data.selectedDay?.id, 'mon');
      expect(data.selectedDay?.isSelected, isTrue);
    });

    test('teacherTimetableEmptyProvider clears schedule days', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(teacherTimetableEmptyProvider.notifier).state = true;
      final data = container.read(teacherTimetableProvider);

      expect(data.days, isEmpty);
      expect(data.selectedDay, isNull);
    });
  });
}
