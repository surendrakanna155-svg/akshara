import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'exam_models.dart';

final studentExamSectionProvider = StateProvider<StudentExamSection>(
  (ref) => StudentExamSection.upcoming,
);

final studentExamsLoadingProvider = StateProvider<bool>((ref) => false);
final studentExamsErrorProvider = StateProvider<bool>((ref) => false);
final studentExamsEmptyProvider = StateProvider<bool>((ref) => false);

final studentExamsFutureProvider = FutureProvider<StudentExamsData>((ref) async {
  return ref.read(studentRepositoryProvider).getExams(query: ref.watch(repositoryQueryProvider));
});

final studentExamsProvider = Provider<StudentExamsData>((ref) {
  final data = watchRepositoryFuture(
    ref,
    ref.watch(studentExamsFutureProvider),
    manualLoading: ref.watch(studentExamsLoadingProvider),
    manualError: ref.watch(studentExamsErrorProvider),
    manualEmpty: ref.watch(studentExamsEmptyProvider),
  );
  // `AsyncValue.value` RETHROWS on an AsyncError, which made this provider —
  // and therefore every screen that reads it — blow up on a failed fetch
  // instead of letting the screen render its error state. `valueOrNull` yields
  // null on error, so the fallback below applies and the screens' explicit
  // `studentExamsErrorProvider` / `AsyncValue.hasError` branches take over.
  final resolved = data ??
      ref.watch(studentExamsFutureProvider).valueOrNull ??
      const StudentExamsData(
        studentName: '',
        classLabel: '',
        upcomingExams: [],
        examResults: [],
        subjectScores: [],
        averagePercent: 0,
        unreadNotifications: 0,
      );

  if (ref.watch(studentExamsEmptyProvider)) {
    return StudentExamsData(
      studentName: resolved.studentName,
      classLabel: resolved.classLabel,
      upcomingExams: const [],
      examResults: const [],
      subjectScores: const [],
      averagePercent: 0,
      unreadNotifications: resolved.unreadNotifications,
      schoolName: resolved.schoolName,
    );
  }

  return resolved;
});
