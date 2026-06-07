import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';
import '../admissions_workflow_actions.dart';
import '../admissions_navigation.dart';
import '../widgets/admissions_module_scaffold.dart';
import 'admissions_approval_provider.dart';
import 'widgets/admissions_approval_queue_table.dart';
import 'widgets/admissions_approval_review_panel.dart';

/// AD-07 — Admission Approval queue and review.
class AdmissionsApprovalScreen extends ConsumerWidget {
  const AdmissionsApprovalScreen({super.key});

  static const List<String> filterLabels = ['Pending', 'All classes'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(admissionsApprovalViewStateProvider);
    final selectedId = ref.watch(admissionsSelectedApprovalIdProvider);
    final isMobile = AdminLayout.isMobile(context);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.approval,
      filters: filterLabels,
      body: AdmissionsAsyncBody<List<ApprovalQueueItem>>(
        state: viewState,
        loadingLabel: 'Loading approval queue',
        emptyMessage: 'No applications awaiting approval.',
        emptyIcon: Icons.verified_user_outlined,
        onRetry: () =>
            retryAdmissionsFuture(ref, admissionsApprovalQueueFutureProvider),
        builder: (queue) {
          final selected = queue.cast<ApprovalQueueItem?>().firstWhere(
                (item) => item?.id == selectedId,
                orElse: () => queue.isEmpty ? null : queue.first,
              );
          final review = selected == null
              ? null
              : ref.watch(admissionsApprovalReviewProvider(selected.id));

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdmissionsApprovalQueueTable(
                  items: queue,
                  selectedId: selectedId ?? selected?.id,
                  onSelect: (item) => ref
                      .read(admissionsSelectedApprovalIdProvider.notifier)
                      .state = item.id,
                ),
                if (review != null) ...[
                  const SizedBox(height: AksharaSpacing.s4),
                  AdmissionsApprovalReviewPanel(
                    review: review,
                    onApprove: () => runApproveAdmission(context, ref, review.queueItem.id),
                    onReject: () => runRejectAdmission(context, ref, review.queueItem.id),
                  ),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AdmissionsApprovalQueueTable(
                  items: queue,
                  selectedId: selectedId ?? selected?.id,
                  onSelect: (item) => ref
                      .read(admissionsSelectedApprovalIdProvider.notifier)
                      .state = item.id,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s4),
              Expanded(
                flex: 2,
                child: review == null
                    ? const SizedBox.shrink()
                    : AdmissionsApprovalReviewPanel(
                        review: review,
                        onApprove: () =>
                            runApproveAdmission(context, ref, review.queueItem.id),
                        onReject: () =>
                            runRejectAdmission(context, ref, review.queueItem.id),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
