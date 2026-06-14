import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import 'management_models.dart';
import 'management_mutations_provider.dart';
import 'management_requests.dart';

Future<void> approveManagementItem(
  BuildContext context,
  WidgetRef ref,
  ManagementApprovalItem approval,
) =>
    _resolveManagementItem(
      context,
      ref,
      approval,
      ManagementApprovalStatus.approved,
    );

Future<void> rejectManagementItem(
  BuildContext context,
  WidgetRef ref,
  ManagementApprovalItem approval,
) =>
    _resolveManagementItem(
      context,
      ref,
      approval,
      ManagementApprovalStatus.rejected,
    );

Future<void> _resolveManagementItem(
  BuildContext context,
  WidgetRef ref,
  ManagementApprovalItem approval,
  ManagementApprovalStatus status,
) async {
  try {
    final result =
        await ref.read(resolveManagementApprovalProvider.notifier).execute(
              ResolveManagementApprovalRequest(
                approvalId: approval.id,
                status: status,
              ),
            );
    if (!context.mounted || result == null) return;

    final actionLabel = status == ManagementApprovalStatus.approved
        ? 'Approved'
        : 'Rejected';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.managementApprovalSuccessSnackbar,
        content: Text('$actionLabel: ${result.title}'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to update approval: $error')),
    );
  }
}
