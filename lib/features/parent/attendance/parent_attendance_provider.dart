import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'attendance_models.dart';

/// Visible month (always normalized to the first day).
final attendanceMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime(2026, 6, 1),
);

/// Currently selected calendar day for highlight + bottom sheet.
final attendanceSelectedDayProvider = StateProvider<DateTime?>(
  (ref) => null,
);

/// When true, absent calendar cells are visually emphasized (KPI tap).
final attendanceHighlightAbsentProvider = StateProvider<bool>(
  (ref) => false,
);

/// Mock attendance payload for the active month.
final parentAttendanceProvider = Provider<AttendanceMonthData>((ref) {
  final month = ref.watch(attendanceMonthProvider);
  final selected = ref.watch(attendanceSelectedDayProvider);
  final base = AttendanceMonthData.mock(month: month);

  return base.withSelectedDay(selected);
});

/// Loading flag reserved for future API integration.
final parentAttendanceLoadingProvider = StateProvider<bool>((ref) => false);
