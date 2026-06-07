import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../admissions/admissions_models.dart';
import '../../admissions/fee_handoff/admissions_fee_handoff_provider.dart';
import '../finance_models.dart';

/// Generated fee accounts keyed by handoff id.
final financeGeneratedAccountsProvider =
    StateProvider<Map<String, GeneratedFeeAccountPreview>>((ref) => {});

final financeHandoffQueueProvider = Provider<List<FinanceHandoffQueueItem>>(
  (ref) {
    final handoffs = ref.watch(admissionsApprovedHandoffsProvider);
    return [
      for (final handoff in handoffs)
        FinanceHandoffQueueItem(
          handoff: handoff,
          effectiveStatus: handoff.handoffStatus,
        ),
    ];
  },
);

/// Pending handoffs awaiting finance assignment.
final financePendingHandoffsProvider = Provider<List<FinanceHandoffQueueItem>>(
  (ref) {
    final queue = ref.watch(financeHandoffQueueProvider);
    return queue
        .where(
          (item) =>
              item.effectiveStatus == FeeHandoffStatus.pending ||
              item.effectiveStatus == FeeHandoffStatus.sentToFinance,
        )
        .toList(growable: false);
  },
);

/// Marks a handoff as completed and stores the generated fee account preview.
void completeFinanceHandoffAssignment(
  WidgetRef ref, {
  required String handoffId,
  required GeneratedFeeAccountPreview preview,
}) {
  ref.read(feeHandoffStatusOverridesProvider.notifier).update(
        (state) => {...state, handoffId: FeeHandoffStatus.completed},
      );
  ref.read(financeGeneratedAccountsProvider.notifier).update(
        (state) => {...state, handoffId: preview},
      );
}
