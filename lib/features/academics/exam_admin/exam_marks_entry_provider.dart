import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/approvals/adapters/exam_results_approval_adapter.dart';
import '../../../core/config/exam_approval_config.dart';
import '../../../core/exams/exam_administration_requests.dart';
import '../../../core/exams/exam_administration_store.dart';
import '../../../core/exams/exam_remark.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/erp_role.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../features/auth/auth_provider.dart';
import 'exam_administration_provider.dart';
import '../../../core/errors/mutation_in_progress.dart';

final examMarksExamProvider = FutureProvider.family<ExamSession?, String>(
  (ref, examId) async {
    ref.watch(examAdminRefreshTickProvider);
    return ref.read(examAdministrationRepositoryProvider).getExam(
          query: ref.watch(repositoryQueryProvider),
          examId: examId,
        );
  },
);

final examMarksListProvider =
    FutureProvider.family<List<ExamMarkRecord>, String>((ref, examId) async {
  ref.watch(examAdminRefreshTickProvider);
  return ref.read(examAdministrationRepositoryProvider).listMarks(
        query: ref.watch(repositoryQueryProvider),
        examId: examId,
      );
});

final examMarksMutationProvider =
    AsyncNotifierProvider<ExamMarksMutationNotifier, void>(
  ExamMarksMutationNotifier.new,
);

class ExamMarksMutationNotifier extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<ExamMarkRecord> updateMark({
    required String markEntryId,
    required int marksObtained,
  }) async {
    final rbac = ref.read(rbacServiceProvider);
    if (!rbac.hasPermission(Permission.manageExamMarks)) {
      throw ApiFailureException(
        const ApiFailure(
          type: ApiFailureType.forbidden,
          message: 'You do not have permission to enter exam marks.',
          code: 'RBAC_MANAGEEXAMMARKS',
        ),
      );
    }

    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    late ExamMarkRecord updated;
    state = await AsyncValue.guard(() async {
      updated = await ref.read(examAdministrationRepositoryProvider).updateMark(
            query: ref.read(repositoryQueryProvider),
            request: UpdateExamMarkRequest(
              markEntryId: markEntryId,
              marksObtained: marksObtained,
            ),
          );
      ref.read(examAdminRefreshTickProvider.notifier).state++;
    });
    if (state.hasError) throw state.error!;
    return updated;
  }

  Future<ExamSession> processResults(String examId) async {
    final rbac = ref.read(rbacServiceProvider);
    if (!rbac.hasPermission(Permission.manageExams)) {
      throw ApiFailureException(
        const ApiFailure(
          type: ApiFailureType.forbidden,
          message: 'You do not have permission to process exam results.',
          code: 'RBAC_MANAGEEXAMS',
        ),
      );
    }

    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(examAdministrationRepositoryProvider).processResults(
            query: ref.read(repositoryQueryProvider),
            examId: examId,
          );
      ref.read(examAdminRefreshTickProvider.notifier).state++;
    });
    if (state.hasError) throw state.error!;
    final exam = await ref.read(examAdministrationRepositoryProvider).getExam(
          query: ref.read(repositoryQueryProvider),
          examId: examId,
        );
    return exam!;
  }

  Future<void> verifyCoordinatorResults(String examId) async {
    final rbac = ref.read(rbacServiceProvider);
    if (!rbac.hasPermission(Permission.verifyExamResults)) {
      throw ApiFailureException(
        const ApiFailure(
          type: ApiFailureType.forbidden,
          message:
              'You do not have permission to verify exam results as coordinator.',
          code: 'RBAC_VERIFYEXAMRESULTS',
        ),
      );
    }

    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auth = ref.read(authProvider);
      await ref.read(examAdministrationRepositoryProvider).verifyCoordinatorResults(
            query: ref.read(repositoryQueryProvider),
            examId: examId,
            verifiedBy: auth.displayName ?? auth.claims?.userId ?? 'coordinator',
          );
      ref.read(examAdminRefreshTickProvider.notifier).state++;
    });
    if (state.hasError) throw state.error!;
  }

  Future<String> submitForApproval(String examId) async {
    final rbac = ref.read(rbacServiceProvider);
    if (!rbac.hasPermission(Permission.submitExamResults)) {
      throw ApiFailureException(
        const ApiFailure(
          type: ApiFailureType.forbidden,
          message: 'You do not have permission to submit exam results.',
          code: 'RBAC_SUBMITEXAMRESULTS',
        ),
      );
    }

    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    late String approvalId;
    state = await AsyncValue.guard(() async {
      final auth = ref.read(authProvider);
      final adapter = ExamResultsApprovalAdapter();
      final approval = await adapter.submitForApproval(
        service: ref.read(approvalCenterServiceProvider),
        query: ref.read(repositoryQueryProvider),
        examId: examId,
        requesterId: auth.claims?.userId ?? 'erp_demo',
        requesterName: auth.displayName ?? 'Exam Coordinator',
      );
      approvalId = approval.id;
      ref.read(examAdminRefreshTickProvider.notifier).state++;
    });
    if (state.hasError) throw state.error!;
    return approvalId;
  }

  Future<int> publishDirect(String examId) async {
    if (ref.read(examApprovalRequiredProvider)) {
      throw ApiFailureException(
        const ApiFailure(
          type: ApiFailureType.forbidden,
          message:
              'Direct publish is disabled. Submit results for principal approval.',
          code: 'EXAM_APPROVAL_REQUIRED',
        ),
      );
    }
    final rbac = ref.read(rbacServiceProvider);
    if (!rbac.hasPermission(Permission.publishExamResults)) {
      throw ApiFailureException(
        const ApiFailure(
          type: ApiFailureType.forbidden,
          message: 'You do not have permission to publish exam results.',
          code: 'RBAC_PUBLISHEXAMRESULTS',
        ),
      );
    }

    if (state.isLoading) throw mutationInProgressFailure();
    state = const AsyncLoading();
    late int count;
    state = await AsyncValue.guard(() async {
      count = await ref.read(examAdministrationRepositoryProvider).publishResults(
            query: ref.read(repositoryQueryProvider),
            examId: examId,
          );
      ref.read(examAdminRefreshTickProvider.notifier).state++;
    });
    if (state.hasError) throw state.error!;
    return count;
  }
}

/// The leadership remark author role for the current user, or null when they are
/// neither principal nor vice-principal. A user holding both resolves to
/// principal (the senior role).
final examLeadershipRemarkRoleProvider =
    Provider<ExamRemarkAuthorRole?>((ref) {
  final rbac = ref.watch(rbacServiceProvider);
  if (rbac.hasRole(ErpRole.principal)) return ExamRemarkAuthorRole.principal;
  if (rbac.hasRole(ErpRole.vicePrincipal)) {
    return ExamRemarkAuthorRole.vicePrincipal;
  }
  return null;
});

/// Whether the current user may author the leadership (principal/VP) remark.
final canAuthorLeadershipExamRemarkProvider = Provider<bool>((ref) {
  return ref.watch(examLeadershipRemarkRoleProvider) != null;
});

/// Current leadership remark text for a (student, exam session), if any.
String? leadershipExamRemarkText(
  WidgetRef ref,
  String examId,
  String sisStudentId,
) {
  ref.watch(examAdminRefreshTickProvider);
  return ExamAdministrationStore.instance
      .remarkFor(examId, sisStudentId, leadership: true)
      ?.text;
}

/// Principal / vice-principal creates or edits the leadership remark for a
/// (student, exam session). Throws when the user holds neither leadership role.
Future<void> saveLeadershipExamRemark(
  WidgetRef ref, {
  required String examId,
  required String sisStudentId,
  required String text,
}) async {
  final role = ref.read(examLeadershipRemarkRoleProvider);
  if (role == null) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'Only the principal or vice-principal may add this remark.',
        code: 'RBAC_LEADERSHIP_EXAM_REMARK',
      ),
    );
  }
  final auth = ref.read(authProvider);
  final roleLabel = role == ExamRemarkAuthorRole.principal
      ? 'Principal'
      : 'Vice Principal';
  // Persist through the repository (backend in live mode), then cache the
  // canonical remark so synchronous reads reflect it immediately.
  final remark = await ref.read(examAdministrationRepositoryProvider).upsertRemark(
        query: ref.read(repositoryQueryProvider),
        examId: examId,
        sisStudentId: sisStudentId,
        text: text.trim(),
        authorName: auth.displayName ?? roleLabel,
        authorRole: role,
      );
  ExamAdministrationStore.instance.cacheRemarks([remark]);
  ref.read(examAdminRefreshTickProvider.notifier).state++;
}
