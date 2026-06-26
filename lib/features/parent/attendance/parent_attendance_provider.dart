import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../parent_active_child_provider.dart';
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

final parentAttendanceLoadingProvider = StateProvider<bool>((ref) => false);
final parentAttendanceErrorProvider = StateProvider<bool>((ref) => false);
final parentAttendanceEmptyProvider = StateProvider<bool>((ref) => false);

final parentAttendanceFutureProvider = FutureProvider<AttendanceMonthData>((ref) async {
  final month = ref.watch(attendanceMonthProvider);
  return ref.read(parentRepositoryProvider).getAttendance(
        query: ref.watch(parentRepositoryQueryProvider),
        month: month,
      );
});

final parentAttendanceProvider = Provider<AttendanceMonthData>((ref) {
  final selected = ref.watch(attendanceSelectedDayProvider);
  final base = watchRepositoryFuture(
    ref,
    ref.watch(parentAttendanceFutureProvider),
    manualLoading: ref.watch(parentAttendanceLoadingProvider),
    manualError: ref.watch(parentAttendanceErrorProvider),
    manualEmpty: ref.watch(parentAttendanceEmptyProvider),
  );
  final month = ref.watch(attendanceMonthProvider);
  final resolved = base ??
      ref.watch(parentAttendanceFutureProvider).value ??
      AttendanceMonthData.mock(month: month);
  return resolved.withSelectedDay(selected);
});
