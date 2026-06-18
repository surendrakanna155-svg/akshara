import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/approvals/adapters/exam_results_approval_adapter.dart';
import '../../../core/config/exam_approval_config.dart';
import '../../../core/errors/api_failure.dart';
import '../../../core/exams/exam_administration_requests.dart';
import '../../../core/exams/exam_administration_store.dart';
import '../../../core/repositories/interfaces/exam_administration_repository.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../features/auth/auth_provider.dart';
import 'exam_administration_provider.dart';

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
  Future<void> build() async {}

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
