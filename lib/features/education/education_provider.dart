import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import 'education_models.dart';

final educationQueryProvider = Provider<RepositoryQuery>(
  (ref) => ref.watch(repositoryQueryProvider),
);

final educationCanViewProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewEducation);
});

final educationCanManageProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.manageEducation);
});

final questionBankListProvider = FutureProvider<List<QuestionBankItem>>((ref) async {
  return ref.read(educationRepositoryProvider).listQuestionBank(
        query: ref.watch(educationQueryProvider),
      );
});

final questionPapersListProvider = FutureProvider<List<QuestionPaperSummary>>((ref) async {
  return ref.read(educationRepositoryProvider).listQuestionPapers(
        query: ref.watch(educationQueryProvider),
      );
});

final homeworkListProvider = FutureProvider<List<HomeworkAssignment>>((ref) async {
  return ref.read(educationRepositoryProvider).listHomework(
        query: ref.watch(educationQueryProvider),
      );
});

final reportRemarksListProvider = FutureProvider<List<ReportCardRemark>>((ref) async {
  return ref.read(educationRepositoryProvider).listReportRemarks(
        query: ref.watch(educationQueryProvider),
      );
});

final educationSelectedPaperIdProvider = StateProvider<String?>((ref) => null);

final educationSelectedPaperProvider = FutureProvider<QuestionPaperDetail?>((ref) async {
  final id = ref.watch(educationSelectedPaperIdProvider);
  if (id == null) return null;
  return ref.read(educationRepositoryProvider).getQuestionPaper(
        query: ref.watch(educationQueryProvider),
        paperId: id,
      );
});

final educationMutationsProvider =
    AsyncNotifierProvider<EducationMutationsNotifier, void>(EducationMutationsNotifier.new);

class EducationMutationsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<QuestionPaperDetail> generatePaper(GenerateQuestionPaperRequest request) async {
    state = const AsyncLoading();
    try {
      final detail = await ref.read(educationRepositoryProvider).generateQuestionPaper(
            query: ref.read(educationQueryProvider),
            request: request,
          );
      ref.invalidate(questionPapersListProvider);
      state = const AsyncData(null);
      return detail;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> publishPaper(String paperId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(educationRepositoryProvider).publishQuestionPaper(
            query: ref.read(educationQueryProvider),
            paperId: paperId,
          );
      ref.invalidate(questionPapersListProvider);
    });
  }

  Future<HomeworkAssignment> generateHomework(GenerateHomeworkRequest request) async {
    state = const AsyncLoading();
    final created = await ref.read(educationRepositoryProvider).generateHomework(
          query: ref.read(educationQueryProvider),
          request: request,
        );
    ref.invalidate(homeworkListProvider);
    state = const AsyncData(null);
    return created;
  }

  Future<ReportCardRemark> generateRemark(GenerateReportRemarkRequest request) async {
    state = const AsyncLoading();
    final created = await ref.read(educationRepositoryProvider).generateReportRemark(
          query: ref.read(educationQueryProvider),
          request: request,
        );
    ref.invalidate(reportRemarksListProvider);
    state = const AsyncData(null);
    return created;
  }

  Future<void> updateRemark(String remarkId, String editedRemark) async {
    await ref.read(educationRepositoryProvider).updateReportRemark(
          query: ref.read(educationQueryProvider),
          remarkId: remarkId,
          editedRemark: editedRemark,
        );
    ref.invalidate(reportRemarksListProvider);
  }
}
