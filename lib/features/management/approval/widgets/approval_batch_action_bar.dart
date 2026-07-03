import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/approvals/approval_models.dart';
import '../../../../core/security/permissions.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/akshara_approve_action.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../approval_center_provider.dart';

/// PRI-1 — batch-action bar for the multi-select approval queue. Appears when
/// at least one request is selected. Approve / Reject (mandatory-comment
/// dialog) / Clear. RBAC-gated on `viewManagement` (per-item authority is
/// enforced by the batch notifier + server, surfacing forbidden ids as skips).
class ApprovalBatchActionBar extends ConsumerWidget {
  const ApprovalBatchActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(approvalCenterSelectionProvider);
    if (selection.isEmpty) return const SizedBox.shrink();

    final count = selection.length;
    final busy = ref.watch(batchDecideApprovalsProvider).isLoading;
    final colors = context.colors;

    return AksharaApproveAction(
      permission: Permission.viewManagement,
      child: Semantics(
        container: true,
        label: 'Batch approval actions, $count selected',
        child: Card(
          key: QaTestKeys.approvalBatchBar,
          elevation: 0,
          color: colors.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s3),
            child: Wrap(
              spacing: AksharaSpacing.s3,
              runSpacing: AksharaSpacing.s2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '$count selected',
                  style: context.aksharaText.titleSmall,
                ),
                FilledButton.icon(
                  key: QaTestKeys.approvalBatchApproveButton,
                  onPressed: busy
                      ? null
                      : () => _decide(
                            context,
                            ref,
                            ApprovalBatchDecision.approve,
                          ),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Approve selected'),
                ),
                OutlinedButton.icon(
                  key: QaTestKeys.approvalBatchRejectButton,
                  onPressed: busy
                      ? null
                      : () => _decide(
                            context,
                            ref,
                            ApprovalBatchDecision.reject,
                          ),
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('Reject selected'),
                ),
                TextButton(
                  key: QaTestKeys.approvalBatchClearButton,
                  onPressed: busy
                      ? null
                      : () => ref
                          .read(approvalCenterSelectionProvider.notifier)
                          .state = <String>{},
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    ApprovalBatchDecision decision,
  ) async {
    final selection = ref.read(approvalCenterSelectionProvider);
    if (selection.isEmpty) return;

    String? comment;
    if (decision == ApprovalBatchDecision.reject) {
      comment = await _promptBatchRejectComment(context, selection.length);
      if (comment == null || comment.trim().isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rejection requires a comment.')),
          );
        }
        return;
      }
    }

    // Resolve the selected ids against the current list so the notifier can
    // apply per-item authority by type.
    final items = ref.read(approvalCenterListProvider);
    final requests =
        items.where((item) => selection.contains(item.id)).toList();
    if (requests.isEmpty) return;

    try {
      final result = await ref
          .read(batchDecideApprovalsProvider.notifier)
          .decide(requests: requests, decision: decision, comment: comment);
      if (!context.mounted || result == null) return;

      ref.read(approvalCenterSelectionProvider.notifier).state = <String>{};
      final verb =
          decision == ApprovalBatchDecision.approve ? 'approved' : 'rejected';
      final decided = result.decided.length;
      final skipped = result.skipped.length;
      final skipDetail = skipped == 0
          ? ''
          : ' (${_summariseSkips(result.skipped)})';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.approvalBatchResultSnackbar,
          content: Text('$decided $verb, $skipped skipped$skipDetail'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to complete batch: $error')),
      );
    }
  }

  String _summariseSkips(List<ApprovalBatchSkippedItem> skipped) {
    final counts = <String, int>{};
    for (final item in skipped) {
      // Collapse "forbidden: <perm>" to "forbidden" for the summary line.
      final reason =
          item.reason.startsWith('forbidden') ? 'forbidden' : item.reason;
      counts[reason] = (counts[reason] ?? 0) + 1;
    }
    return counts.entries.map((e) => '${e.value} ${e.key}').join(', ');
  }

  Future<String?> _promptBatchRejectComment(
    BuildContext context,
    int count,
  ) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject $count selected'),
        content: TextField(
          key: QaTestKeys.approvalBatchRejectDialogField,
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
            hintText: 'Explain why these requests are rejected',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.approvalBatchRejectDialogConfirm,
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
