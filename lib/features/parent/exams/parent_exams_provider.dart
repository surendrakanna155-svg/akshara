import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'exam_models.dart';

/// Active section in segmented control.
final parentExamSectionProvider = StateProvider<ExamSection>(
  (ref) => ExamSection.upcoming,
);

final parentExamsLoadingProvider = StateProvider<bool>((ref) => false);
final parentExamsErrorProvider = StateProvider<String?>((ref) => null);
final parentExamsEmptyProvider = StateProvider<bool>((ref) => false);

final parentExamsFutureProvider = FutureProvider<ParentExamsData>((ref) async {
  return ref.read(parentRepositoryProvider).getExams(query: ref.watch(repositoryQueryProvider));
});

final parentExamsProvider = Provider<ParentExamsData>((ref) {
  final empty = ref.watch(parentExamsEmptyProvider);
  final data = watchRepositoryFuture(
    ref,
    ref.watch(parentExamsFutureProvider),
    manualLoading: ref.watch(parentExamsLoadingProvider),
    manualError: ref.watch(parentExamsErrorProvider) != null,
    manualEmpty: ref.watch(parentExamsEmptyProvider),
  );
  final resolved = data ??
      ref.watch(parentExamsFutureProvider).value ??
      ParentExamsData.mock();
  if (!empty) {
    return resolved;
  }
  return resolved.copyWith(
    upcomingExams: const [],
    examResults: const [],
  );
});
