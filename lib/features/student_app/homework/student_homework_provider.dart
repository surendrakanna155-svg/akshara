import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../dashboard/student_dashboard_provider.dart';
import '../student_mutations_provider.dart';
import '../student_requests.dart';
import 'homework_models.dart';

final studentHomeworkFilterProvider = StateProvider<StudentHomeworkFilter>(
  (ref) => StudentHomeworkFilter.all,
);

final studentHomeworkLoadingProvider = StateProvider<bool>((ref) => false);
final studentHomeworkErrorProvider = StateProvider<bool>((ref) => false);
final studentHomeworkEmptyProvider = StateProvider<bool>((ref) => false);

final studentHomeworkFutureProvider = FutureProvider<List<StudentHomeworkItem>>((ref) async {
  return ref.read(studentRepositoryProvider).getHomeworkItems(
        query: ref.watch(repositoryQueryProvider),
      );
});

final _studentHomeworkItemsProvider = Provider<List<StudentHomeworkItem>>((ref) {
  final items = watchRepositoryFuture(
    ref,
    ref.watch(studentHomeworkFutureProvider),
    manualLoading: ref.watch(studentHomeworkLoadingProvider),
    manualError: ref.watch(studentHomeworkErrorProvider),
    manualEmpty: ref.watch(studentHomeworkEmptyProvider),
  );
  return items ?? ref.watch(studentHomeworkFutureProvider).value ?? const [];
});

final studentHomeworkItemsProvider = Provider<List<StudentHomeworkItem>>((ref) {
  if (ref.watch(studentHomeworkEmptyProvider)) return const [];

  final filter = ref.watch(studentHomeworkFilterProvider);
  final items = ref.watch(_studentHomeworkItemsProvider);

  return switch (filter) {
    StudentHomeworkFilter.all => items,
    StudentHomeworkFilter.pending => items
        .where(
          (i) =>
              i.status == StudentHomeworkStatus.pending ||
              i.status == StudentHomeworkStatus.overdue,
        )
        .toList(growable: false),
    StudentHomeworkFilter.submitted => items
        .where((i) => i.status.isSubmitted)
        .toList(growable: false),
  };
});

final studentHomeworkProvider = Provider<StudentHomeworkData>((ref) {
  final dash = ref.watch(studentDashboardFutureProvider).value;
  return StudentHomeworkData(
    studentName: dash?.studentName ?? '',
    classLabel: dash?.classLabel ?? '',
    unreadNotifications: dash?.unreadNotifications ?? 0,
    items: ref.watch(studentHomeworkItemsProvider),
  );
});

Future<bool> submitStudentHomework(WidgetRef ref, String homeworkId) async {
  final result = await ref.read(submitStudentHomeworkProvider.notifier).execute(
        StudentHomeworkSubmitRequest(homeworkId: homeworkId),
      );
  if (result != null) {
    ref.invalidate(studentHomeworkFutureProvider);
    return true;
  }
  return false;
}
