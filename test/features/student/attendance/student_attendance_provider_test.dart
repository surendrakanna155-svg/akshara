import 'package:akshara_erp/features/student/attendance/student_attendance_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('studentAttendance providers', () {
    test('studentAttendanceProvider exposes monthly data for Ravi Kumar', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(studentAttendanceProvider);

      expect(data.childName, 'Ravi Kumar');
      expect(data.childClass, '8-A');
      expect(data.calendarDays, isNotEmpty);
      expect(data.kpi.attendancePercent, greaterThan(0));
    });

    test('studentAttendanceMonthProvider changes visible month', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(studentAttendanceMonthProvider.notifier).state =
          DateTime(2026, 5, 1);
      final data = container.read(studentAttendanceProvider);

      expect(data.month.month, 5);
    });

    test('studentAttendanceInsightProvider derives AI message', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final insight = container.read(studentAttendanceInsightProvider);

      expect(insight.message, contains('attendance'));
      expect(insight.actionLabel, isNotEmpty);
    });
  });
}
