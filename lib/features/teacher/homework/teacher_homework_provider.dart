import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../teacher_mutations_provider.dart';
import '../teacher_requests.dart';
import 'homework_models.dart';

final teacherHomeworkAssignmentProvider = StateProvider<String>(
  (ref) => 'hw_8a_1',
);

final teacherHomeworkLoadingProvider = StateProvider<bool>((ref) => false);
final teacherHomeworkErrorProvider = StateProvider<bool>((ref) => false);
final teacherHomeworkEmptyProvider = StateProvider<bool>((ref) => false);
final teacherHomeworkCreatedAssignmentsProvider =
    StateProvider<List<TeacherHomeworkAssignment>>((ref) => const []);

final teacherHomeworkFutureProvider =
    FutureProvider<List<TeacherHomeworkAssignment>>((ref) async {
  return ref.read(teacherRepositoryProvider).getHomeworkAssignments(
        query: ref.watch(repositoryQueryProvider),
      );
});

final _teacherHomeworkSubmissionsProvider =
    StateProvider<Map<String, List<HomeworkSubmission>>?>((ref) => null);

List<TeacherHomeworkAssignment> _assignments(Ref ref) {
  final override = ref.watch(_teacherHomeworkSubmissionsProvider);
  final base = watchRepositoryFuture(
    ref,
    ref.watch(teacherHomeworkFutureProvider),
    manualLoading: ref.watch(teacherHomeworkLoadingProvider),
    manualError: ref.watch(teacherHomeworkErrorProvider),
    manualEmpty: ref.watch(teacherHomeworkEmptyProvider),
  ) ??
      ref.watch(teacherHomeworkFutureProvider).value ??
      const <TeacherHomeworkAssignment>[];

  final created = ref.watch(teacherHomeworkCreatedAssignmentsProvider);
  final all = [...base, ...created];

  if (override == null) return all;
  return [
    for (final assignment in all)
      TeacherHomeworkAssignment(
        id: assignment.id,
        title: assignment.title,
        classLabel: assignment.classLabel,
        dueLabel: assignment.dueLabel,
        submissions: override[assignment.id] ?? assignment.submissions,
      ),
  ];
}

final teacherHomeworkAssignmentsProvider = Provider<List<TeacherHomeworkAssignment>>((ref) {
  if (ref.watch(teacherHomeworkEmptyProvider)) return const [];
  return _assignments(ref);
});

final teacherHomeworkProvider = Provider<TeacherHomeworkAssignment?>((ref) {
  final id = ref.watch(teacherHomeworkAssignmentProvider);
  final assignments = ref.watch(teacherHomeworkAssignmentsProvider);
  for (final item in assignments) {
    if (item.id == id) return item;
  }
  return assignments.isEmpty ? null : assignments.first;
});

Future<void> reviewSubmission(
  WidgetRef ref, {
  required String assignmentId,
  required String submissionId,
  required String grade,
  required String comment,
}) async {
  final result = await ref.read(reviewTeacherHomeworkProvider.notifier).execute(
        TeacherHomeworkReviewRequest(
          submissionId: submissionId,
          grade: grade,
          comment: comment,
        ),
      );
  if (result == null) return;

  final override = ref.read(_teacherHomeworkSubmissionsProvider);
  final base = ref.read(teacherHomeworkFutureProvider).value ??
      const <TeacherHomeworkAssignment>[];
  final assignments = override == null
      ? base
      : [
          for (final assignment in base)
            TeacherHomeworkAssignment(
              id: assignment.id,
              title: assignment.title,
              classLabel: assignment.classLabel,
              dueLabel: assignment.dueLabel,
              submissions: override[assignment.id] ?? assignment.submissions,
            ),
        ];
  final map = <String, List<HomeworkSubmission>>{};
  for (final assignment in assignments) {
    map[assignment.id] = assignment.submissions;
  }
  final list = map[assignmentId];
  if (list == null) return;
  map[assignmentId] = [
    for (final item in list)
      item.id == submissionId
          ? item.copyWith(
              status: HomeworkReviewStatus.reviewed,
              grade: grade,
              comment: comment,
            )
          : item,
  ];
  ref.read(_teacherHomeworkSubmissionsProvider.notifier).state = map;
}
