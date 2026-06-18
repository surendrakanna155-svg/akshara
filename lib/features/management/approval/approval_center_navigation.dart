import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/approvals/approval_category.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import 'approval_center_provider.dart';

/// Opens the unified Principal Approval Center with optional category pre-filter.
void openPrincipalApprovalCenter(
  BuildContext context,
  WidgetRef ref, {
  ApprovalCategory category = ApprovalCategory.all,
  bool pendingOnly = true,
}) {
  ref.read(approvalCenterCategoryFilterProvider.notifier).state = category;
  ref.read(approvalCenterStatusFilterProvider.notifier).state =
      pendingOnly ? 1 : 0;
  ref.read(approvalCenterSelectedIdProvider.notifier).state = null;
  context.go(RouteNames.managementApprovals);
}

/// Inline CTA when module screens defer approve/reject to the unified inbox.
class ApprovalCenterRedirectBanner extends ConsumerWidget {
  const ApprovalCenterRedirectBanner({
    super.key,
    required this.message,
    this.category = ApprovalCategory.all,
    this.pendingOnly = true,
    this.compact = false,
  });

  final String message;
  final ApprovalCategory category;
  final bool pendingOnly;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final button = FilledButton.icon(
      key: QaTestKeys.openApprovalCenterButton,
      onPressed: () => openPrincipalApprovalCenter(
        context,
        ref,
        category: category,
        pendingOnly: pendingOnly,
      ),
      icon: const Icon(Icons.inbox_outlined, size: 18),
      label: const Text('Open Approval Center'),
    );

    if (compact) {
      return button;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            button,
          ],
        ),
      ),
    );
  }
}
