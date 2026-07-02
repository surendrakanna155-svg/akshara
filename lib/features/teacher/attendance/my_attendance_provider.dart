import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'my_attendance_models.dart';

/// TCH-9 — the month currently shown on the My Attendance screen (`YYYY-MM`).
/// Null means "current month" (the backend defaults it server-side).
final myAttendanceMonthProvider = StateProvider<String?>((ref) => null);

/// TCH-9 — the caller's OWN attendance history for a given month (`YYYY-MM`, or
/// null for the current month). READ-ONLY, self-scoped by the backend.
final myAttendanceHistoryProvider =
    FutureProvider.family<MyAttendanceHistory, String?>((ref, month) async {
  return ref.read(teacherRepositoryProvider).getMyAttendanceHistory(
        query: ref.watch(repositoryQueryProvider),
        month: month,
      );
});
