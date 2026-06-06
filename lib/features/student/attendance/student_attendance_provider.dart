import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../parent/attendance/attendance_models.dart';

final studentAttendanceMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime(2026, 6, 1),
);

final studentAttendanceSelectedDayProvider = StateProvider<DateTime?>(
  (ref) => null,
);

final studentAttendanceHighlightAbsentProvider = StateProvider<bool>(
  (ref) => false,
);

final studentAttendanceLoadingProvider = StateProvider<bool>((ref) => false);
final studentAttendanceErrorProvider = StateProvider<bool>((ref) => false);

final studentAttendanceProvider = Provider<AttendanceMonthData>((ref) {
  final month = ref.watch(studentAttendanceMonthProvider);
  final selected = ref.watch(studentAttendanceSelectedDayProvider);
  return AttendanceMonthData.mock(month: month).withSelectedDay(selected);
});

/// AI attendance insight for ST-02.
final studentAttendanceInsightProvider = Provider<StudentAttendanceInsight>(
  (ref) {
    final data = ref.watch(studentAttendanceProvider);
    return StudentAttendanceInsight(
      message:
          'Your attendance is ${data.kpi.attendancePercent}% this month. '
          'Avoid more than 2 late marks to stay in the green zone.',
      actionLabel: 'View tips',
    );
  },
);

class StudentAttendanceInsight {
  const StudentAttendanceInsight({
    required this.message,
    required this.actionLabel,
  });

  final String message;
  final String actionLabel;
}
