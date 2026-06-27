import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../core/repositories/repository_query.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/errors/api_failure.dart';
import 'education_models.dart';
import '../../core/errors/mutation_in_progress.dart';

void assertManageEducation(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null || !perms.has(Permission.manageEducation)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage Education.',
        code: 'RBAC_MANAGE_EDUCATION',
      ),
    );
  }
}

/// Validation (approve / request changes / publish) is principal-level only.
void assertApproveEducation(Ref ref) {
  final perms = ref.read(userPermissionsProvider);
  if (perms == null || !perms.has(Permission.approveEducation)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'Only a principal-level reviewer can validate question papers.',
        code: 'RBAC_APPROVE_EDUCATION',
      ),
    );
  }
}

final educationQueryProvider = Provider<RepositoryQuery>(
  (ref) => ref.watch(repositoryQueryProvider),
);

final educationCanViewProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewEducation);
});

final educationCanManageProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.manageEducation);
});

/// True only for principal-level reviewers who may validate (approve / publish).
final educationCanApproveProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.approveEducation);
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

/// Full detail (paper + items) for a given paper id, used by the detail screen.
final paperDetailProvider =
    FutureProvider.family<QuestionPaperDetail, String>((ref, paperId) async {
  return ref.read(educationRepositoryProvider).getQuestionPaper(
        query: ref.watch(educationQueryProvider),
        paperId: paperId,
      );
});

/// Reviews trail for a given paper (governance history).
final paperReviewsProvider =
    FutureProvider.family<List<PaperReview>, String>((ref, paperId) async {
  return ref.read(educationRepositoryProvider).listPaperReviews(
        query: ref.watch(educationQueryProvider),
        paperId: paperId,
      );
});

/// Holds the most recent generation result so the screen can surface the
/// "N marks unfilled" banner and the AI-candidate moderation prompt.
final lastGeneratedPaperProvider = StateProvider<QuestionPaperDetail?>((ref) => null);

final educationMutationsProvider =
    AsyncNotifierProvider<EducationMutationsNotifier, void>(EducationMutationsNotifier.new);

class EducationMutationsNotifier extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<QuestionPaperDetail> generatePaper(GenerateQuestionPaperRequest request) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      assertManageEducation(ref);
      final detail = await ref.read(educationRepositoryProvider).generateQuestionPaper(
            query: ref.read(educationQueryProvider),
            request: request,
          );
      ref.read(lastGeneratedPaperProvider.notifier).state = detail;
      ref.invalidate(questionPapersListProvider);
      state = const AsyncData(null);
      return detail;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<QuestionPaperSummary> publishPaper(String paperId) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      assertApproveEducation(ref);
      final paper = await ref.read(educationRepositoryProvider).publishQuestionPaper(
            query: ref.read(educationQueryProvider),
            paperId: paperId,
          );
      _invalidatePaper(paperId);
      state = const AsyncData(null);
      return paper;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<QuestionPaperSummary> submitPaper(String paperId) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      assertManageEducation(ref);
      final paper = await ref.read(educationRepositoryProvider).submitQuestionPaper(
            query: ref.read(educationQueryProvider),
            paperId: paperId,
          );
      _invalidatePaper(paperId);
      state = const AsyncData(null);
      return paper;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<QuestionPaperSummary> reviewPaper(
    String paperId,
    String decision, {
    String? comments,
  }) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      assertApproveEducation(ref);
      final paper = await ref.read(educationRepositoryProvider).reviewQuestionPaper(
            query: ref.read(educationQueryProvider),
            paperId: paperId,
            decision: decision,
            comments: comments,
          );
      _invalidatePaper(paperId);
      state = const AsyncData(null);
      return paper;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<QuestionPaperItem> moderateItem(
    String paperId,
    String itemId,
    String decision,
  ) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      assertManageEducation(ref);
      final item = await ref.read(educationRepositoryProvider).moderatePaperItem(
            query: ref.read(educationQueryProvider),
            paperId: paperId,
            itemId: itemId,
            decision: decision,
          );
      _invalidatePaper(paperId);
      state = const AsyncData(null);
      return item;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Feature C — edit a saved bank question.
  Future<QuestionBankItem> updateBankItem(QuestionBankItem item) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      assertManageEducation(ref);
      final updated = await ref.read(educationRepositoryProvider).updateQuestionBankItem(
            query: ref.read(educationQueryProvider),
            item: item,
          );
      ref.invalidate(questionBankListProvider);
      state = const AsyncData(null);
      return updated;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Feature A — fix one question inside a paper (token-free).
  Future<QuestionPaperItem> editPaperItem(
    String paperId,
    String itemId, {
    EduQuestionType? questionType,
    int? marks,
    String? questionText,
    String? answerText,
    List<String>? options,
  }) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      assertManageEducation(ref);
      final item = await ref.read(educationRepositoryProvider).updatePaperItem(
            query: ref.read(educationQueryProvider),
            paperId: paperId,
            itemId: itemId,
            questionType: questionType,
            marks: marks,
            questionText: questionText,
            answerText: answerText,
            options: options,
          );
      _invalidatePaper(paperId);
      state = const AsyncData(null);
      return item;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Feature B — regenerate one slot with AI (spends tokens).
  Future<QuestionPaperItem> regenerateItem(
    String paperId,
    String itemId, {
    String? chapter,
  }) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      assertManageEducation(ref);
      final item = await ref.read(educationRepositoryProvider).regeneratePaperItem(
            query: ref.read(educationQueryProvider),
            paperId: paperId,
            itemId: itemId,
            chapter: chapter,
          );
      _invalidatePaper(paperId);
      state = const AsyncData(null);
      return item;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Feature E — save an approved AI candidate into the reusable bank.
  Future<QuestionBankItem> promoteItemToBank(
    String paperId,
    String itemId, {
    String? chapter,
    String? topic,
    EduDifficulty? difficulty,
    EduCognitiveLevel? cognitiveLevel,
    String? syllabusChapterId,
  }) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      assertManageEducation(ref);
      final created = await ref.read(educationRepositoryProvider).promotePaperItemToBank(
            query: ref.read(educationQueryProvider),
            paperId: paperId,
            itemId: itemId,
            chapter: chapter,
            topic: topic,
            difficulty: difficulty,
            cognitiveLevel: cognitiveLevel,
            syllabusChapterId: syllabusChapterId,
          );
      ref.invalidate(questionBankListProvider);
      state = const AsyncData(null);
      return created;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void _invalidatePaper(String paperId) {
    ref.invalidate(questionPapersListProvider);
    ref.invalidate(educationSelectedPaperProvider);
    ref.invalidate(paperDetailProvider(paperId));
    ref.invalidate(paperReviewsProvider(paperId));
  }

  Future<HomeworkAssignment> generateHomework(GenerateHomeworkRequest request) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    assertManageEducation(ref);
    final created = await ref.read(educationRepositoryProvider).generateHomework(
          query: ref.read(educationQueryProvider),
          request: request,
        );
    ref.invalidate(homeworkListProvider);
    state = const AsyncData(null);
    return created;
  }

  Future<ReportCardRemark> generateRemark(GenerateReportRemarkRequest request) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    assertManageEducation(ref);
    final created = await ref.read(educationRepositoryProvider).generateReportRemark(
          query: ref.read(educationQueryProvider),
          request: request,
        );
    ref.invalidate(reportRemarksListProvider);
    state = const AsyncData(null);
    return created;
  }

  Future<void> updateRemark(String remarkId, String editedRemark) async {
    assertManageEducation(ref);
    await ref.read(educationRepositoryProvider).updateReportRemark(
          query: ref.read(educationQueryProvider),
          remarkId: remarkId,
          editedRemark: editedRemark,
        );
    ref.invalidate(reportRemarksListProvider);
  }

  Future<ReportCardRemark> publishRemark(String remarkId) async {
    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    try {
      assertManageEducation(ref);
      final published = await ref.read(educationRepositoryProvider).publishReportRemark(
            query: ref.read(educationQueryProvider),
            remarkId: remarkId,
          );
      ref.invalidate(reportRemarksListProvider);
      state = const AsyncData(null);
      return published;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
