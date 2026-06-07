import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
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
final studentAttendanceEmptyProvider = StateProvider<bool>((ref) => false);

final studentAttendanceFutureProvider = FutureProvider<AttendanceMonthData>((ref) async {
  final month = ref.watch(studentAttendanceMonthProvider);
  return ref.read(studentRepositoryProvider).getAttendance(
        query: ref.watch(repositoryQueryProvider),
        month: month,
      );
});

final studentAttendanceProvider = Provider<AttendanceMonthData>((ref) {
  final month = ref.watch(studentAttendanceMonthProvider);
  final selected = ref.watch(studentAttendanceSelectedDayProvider);
  final base = watchRepositoryFuture(
    ref,
    ref.watch(studentAttendanceFutureProvider),
    manualLoading: ref.watch(studentAttendanceLoadingProvider),
    manualError: ref.watch(studentAttendanceErrorProvider),
    manualEmpty: ref.watch(studentAttendanceEmptyProvider),
  );
  final resolved = base ??
      ref.watch(studentAttendanceFutureProvider).value ??
      AttendanceMonthData.mock(month: month);
  return resolved.withSelectedDay(selected);
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
