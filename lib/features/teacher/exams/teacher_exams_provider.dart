import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_administration_store.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../teacher_mutations_provider.dart';
import '../teacher_requests.dart';
import 'exam_models.dart';

final teacherExamSectionProvider = StateProvider<TeacherExamSection>(
  (ref) => TeacherExamSection.upcoming,
);

final teacherExamsLoadingProvider = StateProvider<bool>((ref) => false);
final teacherExamsErrorProvider = StateProvider<bool>((ref) => false);
final teacherExamsEmptyProvider = StateProvider<bool>((ref) => false);

final teacherUpcomingExamsFutureProvider =
    FutureProvider<List<TeacherUpcomingExam>>((ref) async {
  return ref.read(teacherRepositoryProvider).getUpcomingExams(
        query: ref.watch(repositoryQueryProvider),
      );
});

final teacherExamMarksFutureProvider = FutureProvider<List<ExamMarkEntry>>((ref) async {
  return ref.read(teacherRepositoryProvider).getExamMarks(
        query: ref.watch(repositoryQueryProvider),
      );
});

final _teacherExamMarksProvider = StateProvider<List<ExamMarkEntry>?>((ref) => null);

List<ExamMarkEntry> _marks(Ref ref) {
  final override = ref.watch(_teacherExamMarksProvider);
  if (override != null) return override;
  return watchRepositoryFuture(
    ref,
    ref.watch(teacherExamMarksFutureProvider),
    manualLoading: ref.watch(teacherExamsLoadingProvider),
    manualError: ref.watch(teacherExamsErrorProvider),
    manualEmpty: ref.watch(teacherExamsEmptyProvider),
  ) ??
      ref.watch(teacherExamMarksFutureProvider).value ??
      const <ExamMarkEntry>[];
}

final teacherExamsProvider = Provider<TeacherExamsData>((ref) {
  if (ref.watch(teacherExamsEmptyProvider)) {
    return const TeacherExamsData(
      upcomingExams: [],
      markEntries: [],
      classAveragePercent: 0,
      unreadNotifications: 1,
    );
  }

  final marks = _marks(ref);
  final scored = marks.where((m) => m.marksObtained != null).toList();
  final avg = scored.isEmpty
      ? 0
      : (scored
              .map((m) => m.percent ?? 0)
              .fold<int>(0, (a, b) => a + b) /
          scored.length)
          .round();

  final upcoming = watchRepositoryFuture(
    ref,
    ref.watch(teacherUpcomingExamsFutureProvider),
    manualLoading: ref.watch(teacherExamsLoadingProvider),
    manualError: ref.watch(teacherExamsErrorProvider),
    manualEmpty: ref.watch(teacherExamsEmptyProvider),
  ) ??
      ref.watch(teacherUpcomingExamsFutureProvider).value ??
      const <TeacherUpcomingExam>[];

  return TeacherExamsData(
    upcomingExams: upcoming,
    markEntries: marks,
    classAveragePercent: avg,
    unreadNotifications: 1,
  );
});

Future<void> updateExamMark(WidgetRef ref, String entryId, int marks) async {
  final updated = await ref
      .read(updateTeacherExamMarkProvider.notifier)
      .execute(
        TeacherExamMarkUpdateRequest(
          markEntryId: entryId,
          marksObtained: marks,
        ),
      );
  if (updated == null) return;

  final current = ref.read(_teacherExamMarksProvider) ??
      ref.read(teacherExamMarksFutureProvider).value ??
      const <ExamMarkEntry>[];
  ref.read(_teacherExamMarksProvider.notifier).state = [
    for (final entry in current)
      entry.id == entryId ? entry.copyWith(marksObtained: marks) : entry,
  ];
}

final teacherActiveExamIdProvider = Provider<String?>((ref) {
  ExamAdministrationStore.instance.ensureSeeded();
  return ExamAdministrationStore.instance.activeMarksExamId;
});

Future<TeacherExamPublishResult?> publishExamResults(
  WidgetRef ref,
  String examId,
) async {
  return ref.read(publishTeacherExamResultsProvider.notifier).execute(
        TeacherExamPublishRequest(examId: examId),
      );
}
