import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../admissions_models.dart';

final admissionsApprovalLoadingProvider = StateProvider<bool>((ref) => false);
final admissionsApprovalErrorProvider = StateProvider<bool>((ref) => false);
final admissionsApprovalEmptyProvider = StateProvider<bool>((ref) => false);

final admissionsSelectedApprovalIdProvider = StateProvider<String?>(
  (ref) => null,
);

final admissionsApprovalQueueProvider = Provider<List<ApprovalQueueItem>>((ref) {
  if (ref.watch(admissionsApprovalLoadingProvider)) return const [];
  if (ref.watch(admissionsApprovalErrorProvider)) return const [];
  if (ref.watch(admissionsApprovalEmptyProvider)) return const [];
  return ref.read(admissionsRepositoryProvider).getApprovalQueue();
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

ApprovalReviewDetail _buildReview(ApprovalQueueItem item) {
  return ApprovalReviewDetail(
    queueItem: item,
    feePlanLabel: 'Standard CBSE · 3 installments',
    workflowSteps: const [
      'Application submitted',
      'Documents verified',
      'Counselor recommendation',
      'Principal approval',
      'Fee handoff',
    ],
    counselorNotes: [
      CounselorNote(
        id: 'note_1',
        author: item.counselor,
        timestampLabel: '4 Jun · 2:30 PM',
        content:
            'Strong academic background. Parent prefers morning transport route.',
      ),
      const CounselorNote(
        id: 'note_2',
        author: 'Meera N.',
        timestampLabel: '3 Jun · 11:00 AM',
        content: 'All mandatory documents uploaded except marks memo.',
      ),
    ],
    history: [
      ApprovalHistoryRecord(
        id: 'hist_1',
        timestampLabel: '4 Jun · 9:00 AM',
        actor: item.counselor,
        decision: ApprovalDecision.pending,
        comment: 'Submitted to principal queue',
      ),
      if (item.decision == ApprovalDecision.approved)
        const ApprovalHistoryRecord(
          id: 'hist_2',
          timestampLabel: '2 Jun · 4:15 PM',
          actor: 'Principal Sharma',
          decision: ApprovalDecision.approved,
          comment: 'Approved for Class 10 admission',
        ),
    ],
  );
}
