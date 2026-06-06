import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../admissions_models.dart';
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
    final isLoading = ref.watch(admissionsApprovalLoadingProvider);
    final isError = ref.watch(admissionsApprovalErrorProvider);
    final isEmpty = ref.watch(admissionsApprovalEmptyProvider);
    final queue = ref.watch(admissionsApprovalQueueProvider);
    final selectedId = ref.watch(admissionsSelectedApprovalIdProvider);
    final isMobile = AdminLayout.isMobile(context);

    final selected = queue.cast<ApprovalQueueItem?>().firstWhere(
          (item) => item?.id == selectedId,
          orElse: () => queue.isEmpty ? null : queue.first,
        );
    final review = selected == null
        ? null
        : ref.watch(admissionsApprovalReviewProvider(selected.id));

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.approval,
      filters: filterLabels,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
              child: AksharaLoadingState(
                semanticLabel: 'Loading approval queue',
              ),
            )
          else if (isError)
            const AksharaErrorState(
              message: 'Unable to load approval queue.',
            )
          else if (isEmpty || queue.isEmpty)
            const AksharaEmptyState(
              message: 'No applications awaiting approval.',
              icon: Icons.verified_user_outlined,
            )
          else if (isMobile) ...[
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
                onApprove: () {},
                onReject: () {},
              ),
            ],
          ] else
            Row(
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
                          onApprove: () {},
                          onReject: () {},
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
