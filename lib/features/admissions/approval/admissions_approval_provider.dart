import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tenant/tenant_provider.dart';
import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/paginated_result.dart';
import '../../../core/repositories/repository_query.dart';
import '../../../core/repositories/repository_providers.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';

final admissionsApprovalLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsApprovalErrorProvider = StateProvider<bool>((ref) => false);
final admissionsApprovalEmptyProvider = StateProvider<bool>((ref) => false);
final admissionsApprovalPageProvider = StateProvider<int>((ref) => 1);

final admissionsSelectedApprovalIdProvider = StateProvider<String?>(
  (ref) => null,
);

final admissionsApprovalQueueQueryProvider = Provider<RepositoryQuery>((ref) {
  final baseQuery = ref.watch(repositoryQueryProvider);
  final page = ref.watch(admissionsApprovalPageProvider);
  return baseQuery.withPage(page);
});

final admissionsApprovalQueueFutureProvider =
    FutureProvider<PaginatedResult<ApprovalQueueItem>>((ref) async {
  return ref.read(admissionsRepositoryProvider).getApprovalQueue(
        query: ref.watch(admissionsApprovalQueueQueryProvider),
      );
});

final admissionsApprovalQueuePageResultProvider =
    Provider<PaginatedResult<ApprovalQueueItem>?>((ref) {
  return watchRepositoryFuture(
    ref,
    ref.watch(admissionsApprovalQueueFutureProvider),
    manualLoading: ref.watch(admissionsApprovalLoadingProvider),
    manualError: ref.watch(admissionsApprovalErrorProvider),
    manualEmpty: ref.watch(admissionsApprovalEmptyProvider),
  );
});

final admissionsApprovalQueueProvider =
    Provider<List<ApprovalQueueItem>>((ref) {
  return ref.watch(admissionsApprovalQueuePageResultProvider)?.items ??
      const [];
});

final admissionsApprovalViewStateProvider =
    Provider<AdmissionsViewState<PaginatedResult<ApprovalQueueItem>>>((ref) {
  return resolveAdmissionsAsync(
    ref.watch(admissionsApprovalQueueFutureProvider),
    forceLoading: ref.watch(admissionsApprovalLoadingProvider),
    forceError: ref.watch(admissionsApprovalErrorProvider),
    forceEmpty: ref.watch(admissionsApprovalEmptyProvider),
    isDataEmpty: (result) => result.items.isEmpty,
  );
});

final admissionsApprovalReviewProvider =
    Provider.family<ApprovalReviewDetail?, String>((ref, approvalId) {
  final queue = ref.watch(admissionsApprovalQueueProvider);
  ApprovalQueueItem? item;
  for (final entry in queue) {
    if (entry.id == approvalId) {
      item = entry;
      break;
    }
  }
  if (item == null) return null;
  return _buildReview(item);
});

final admissionsApprovalHistoryProvider =
    Provider<List<ApprovalHistoryRecord>>((ref) {
  final selected = ref.watch(admissionsSelectedApprovalIdProvider);
  if (selected == null) return const [];
  final review = ref.watch(admissionsApprovalReviewProvider(selected));
  return review?.history ?? const [];
});

/// Builds the review detail entirely from the REAL approval-queue row.
///
/// Wave 1 (MJ-H14/MJ-H15) removed the previously hardcoded notes/fee-plan/
/// history fixture. There is no list-notes/list-history read endpoint, so we
/// surface only what is genuinely persisted on the approval row:
///   * `history`  — derived from the row's real decision + submitted label +
///                  counselor (no invented timeline entries).
///   * `counselorNotes` — honest empty until notes are persisted/fetched
///                  (the write path is `POST /admissions/approval/{id}/notes`).
///   * `feePlanLabel` — honest "Not yet assigned": a fee plan is only attached
///                  later at the finance-handoff step, so claiming one here
///                  would be fabricated.
///   * `workflowSteps` — the factual approval process stages (static labels,
///                  not per-application data).
ApprovalReviewDetail _buildReview(ApprovalQueueItem item) {
  return ApprovalReviewDetail(
    queueItem: item,
    feePlanLabel: 'Not yet assigned',
    workflowSteps: const [
      'Application submitted',
      'Documents verified',
      'Counselor recommendation',
      'Principal approval',
      'Fee handoff',
    ],
    counselorNotes: const [],
    history: _deriveHistory(item),
  );
}

/// Derives the approval history from the real queue row. The submission entry
/// always exists (the application reached the principal queue); the decision
/// entry is appended only once a real approve/reject decision is recorded.
List<ApprovalHistoryRecord> _deriveHistory(ApprovalQueueItem item) {
  final actor = item.counselor.isEmpty ? 'Admissions' : item.counselor;
  final records = <ApprovalHistoryRecord>[
    ApprovalHistoryRecord(
      id: '${item.id}_submitted',
      timestampLabel: item.submittedLabel,
      actor: actor,
      decision: ApprovalDecision.pending,
      comment: 'Submitted to principal queue',
    ),
  ];

  if (item.decision == ApprovalDecision.approved) {
    records.add(
      ApprovalHistoryRecord(
        id: '${item.id}_approved',
        timestampLabel: item.submittedLabel,
        actor: 'Principal',
        decision: ApprovalDecision.approved,
        comment: 'Admission approved',
      ),
    );
  } else if (item.decision == ApprovalDecision.rejected) {
    records.add(
      ApprovalHistoryRecord(
        id: '${item.id}_rejected',
        timestampLabel: item.submittedLabel,
        actor: 'Principal',
        decision: ApprovalDecision.rejected,
        comment: 'Admission rejected',
      ),
    );
  }

  return records;
}
