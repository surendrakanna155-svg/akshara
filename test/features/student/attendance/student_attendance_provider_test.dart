import 'package:akshara_erp/features/student/attendance/student_attendance_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('studentAttendance providers', () {
    test('studentAttendanceProvider exposes monthly data for Ravi Kumar', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(studentAttendanceFutureProvider.future);
      final data = container.read(studentAttendanceProvider);

      expect(data.childName, 'Ravi Kumar');
      expect(data.childClass, '8-A');
      expect(data.calendarDays, isNotEmpty);
      expect(data.kpi.attendancePercent, greaterThan(0));
    });

    test('studentAttendanceMonthProvider changes visible month', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(studentAttendanceFutureProvider.future);
      container.read(studentAttendanceMonthProvider.notifier).state =
          DateTime(2026, 5, 1);
      await container.read(studentAttendanceFutureProvider.future);
      final data = container.read(studentAttendanceProvider);

      expect(data.month.month, 5);
    });

    test('studentAttendanceInsightProvider derives AI message', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(studentAttendanceFutureProvider.future);
      final insight = container.read(studentAttendanceInsightProvider);

      expect(insight.message, contains('attendance'));
      expect(insight.actionLabel, isNotEmpty);
    });
  });
}
