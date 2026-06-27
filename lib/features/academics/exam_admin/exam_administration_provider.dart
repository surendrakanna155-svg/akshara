import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exams/exam_administration_requests.dart';
import '../../../core/exams/exam_administration_store.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/repositories/interfaces/exam_administration_repository.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'exam_admin_models.dart';
import '../../../core/errors/mutation_in_progress.dart';

final examAdminPhaseFilterProvider =
    StateProvider<ExamAdminPhaseFilter>((ref) => ExamAdminPhaseFilter.all);

/// Hydrates the local exam-remark cache from the backend for [examId] so that
/// class-teacher and leadership remarks saved on any device survive restart and
/// are visible across devices/roles. Screens that show remarks watch this to
/// trigger the one-time load.
final examRemarksHydrationProvider =
    FutureProvider.family<int, String>((ref, examId) async {
  final remarks =
      await ref.read(examAdministrationRepositoryProvider).listRemarks(
            query: ref.read(repositoryQueryProvider),
            examId: examId,
          );
  ExamAdministrationStore.instance.cacheRemarks(remarks);
  return remarks.length;
});

final examAdministrationListProvider =
    FutureProvider<List<ExamSession>>((ref) async {
  ref.watch(examAdminRefreshTickProvider);
  return ref.read(examAdministrationRepositoryProvider).listExams(
        query: ref.watch(repositoryQueryProvider),
      );
});

final examAdminFilteredListProvider = Provider<AsyncValue<List<ExamSession>>>(
  (ref) {
    final filter = ref.watch(examAdminPhaseFilterProvider);
    return ref.watch(examAdministrationListProvider).whenData(
          (exams) =>
              exams.where((exam) => filter.matches(exam)).toList(growable: false),
        );
  },
);

final examAdminRefreshTickProvider = StateProvider<int>((ref) => 0);

void refreshExamAdminList(WidgetRef ref) {
  ref.read(examAdminRefreshTickProvider.notifier).state++;
}

void _bumpExamAdminListFromNotifier(Ref ref) {
  ref.read(examAdminRefreshTickProvider.notifier).state++;
}

final examAdminMutationProvider =
    AsyncNotifierProvider<ExamAdminMutationNotifier, void>(
  ExamAdminMutationNotifier.new,
);

class ExamAdminMutationNotifier extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<ExamSession> createExam(CreateExamAdministrationRequest request) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(examAdministrationRepositoryProvider).createExam(
            query: ref.read(repositoryQueryProvider),
            request: request,
          );
      _bumpExamAdminListFromNotifier(ref);
    });
    if (state.hasError) throw state.error!;
    _bumpExamAdminListFromNotifier(ref);
    final exams = await ref.read(examAdministrationRepositoryProvider).listExams(
          query: ref.read(repositoryQueryProvider),
        );
    return exams.last;
  }

  Future<ExamSession> scheduleExam(String examId) => _transition(
        examId,
        (repo, query) => repo.scheduleExam(query: query, examId: examId),
      );

  Future<ExamSession> openMarksEntry(String examId) => _transition(
        examId,
        (repo, query) => repo.openMarksEntry(query: query, examId: examId),
      );

  Future<ExamSession> _transition(
    String examId,
    Future<ExamSession> Function(
      ExamAdministrationRepository repo,
      RepositoryQuery query,
    ) action,
  ) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await action(
        ref.read(examAdministrationRepositoryProvider),
        ref.read(repositoryQueryProvider),
      );
      _bumpExamAdminListFromNotifier(ref);
    });
    if (state.hasError) throw state.error!;
    final exam = await ref.read(examAdministrationRepositoryProvider).getExam(
          query: ref.read(repositoryQueryProvider),
          examId: examId,
        );
    return exam!;
  }
}
