import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/akshara_warning_banner.dart';
import '../../../../theme/spacing.dart';
import '../approval_center_provider.dart';

/// PRI-5 — surfaces the already-computed stale (>48h) pending count on the
/// Principal Approval Center. Tapping filters the queue to stale pending items
/// (also forcing the Pending status filter). Toggling again clears the filter.
class ApprovalStaleBanner extends ConsumerWidget {
  const ApprovalStaleBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staleCount = ref.watch(approvalCenterStalePendingCountProvider);
    final staleActive = ref.watch(approvalCenterStaleFilterProvider);
    if (staleCount == 0) return const SizedBox.shrink();

    final plural = staleCount == 1 ? 'approval has' : 'approvals have';
    return Padding(
      padding: const EdgeInsets.only(bottom: AksharaSpacing.s4),
      child: KeyedSubtree(
        key: QaTestKeys.approvalStaleBanner,
        child: AksharaWarningBanner(
          message: '$staleCount pending $plural waited more than 48 hours.',
          semanticLabel: 'Stale approvals warning',
          actionLabel: staleActive ? 'Show all' : 'Review stale',
          alwaysShowAction: true,
          onAction: () {
            final next = !staleActive;
            ref.read(approvalCenterStaleFilterProvider.notifier).state = next;
            // Stale-only implies pending; align the status filter so the
            // filtered list is coherent, and clear stale batch selections.
            if (next) {
              ref.read(approvalCenterStatusFilterProvider.notifier).state = 1;
            }
            ref.read(approvalCenterSelectionProvider.notifier).state =
                <String>{};
          },
        ),
      ),
    );
  }
}
