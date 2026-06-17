import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/approvals/approval_models.dart';
import '../../../core/testing/qa_test_keys.dart';
import 'approval_center_provider.dart';

Future<void> approveApprovalRequest(
  BuildContext context,
  WidgetRef ref,
  ApprovalRequest request,
) async {
  try {
    final result = await ref
        .read(resolveApprovalRequestProvider.notifier)
        .approve(request: request);
    if (!context.mounted || result == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.managementApprovalSuccessSnackbar,
        content: Text('Approved: ${result.title}'),
      ),
    );
    ref.read(approvalCenterSelectedIdProvider.notifier).state = result.id;
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to approve: $error')),
    );
  }
}

Future<void> rejectApprovalRequest(
  BuildContext context,
  WidgetRef ref,
  ApprovalRequest request,
) async {
  final comment = await _promptRejectComment(context, request.title);
  if (comment == null || comment.trim().isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rejection requires a comment.')),
      );
    }
    return;
  }

  try {
    final result = await ref
        .read(resolveApprovalRequestProvider.notifier)
        .reject(request: request, comment: comment);
    if (!context.mounted || result == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.managementApprovalSuccessSnackbar,
        content: Text('Rejected: ${result.title}'),
      ),
    );
    ref.read(approvalCenterSelectedIdProvider.notifier).state = result.id;
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to reject: $error')),
    );
  }
}

Future<String?> _promptRejectComment(
  BuildContext context,
  String title,
) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Reject: $title'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Reason (required)',
          hintText: 'Explain why this request is rejected',
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
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Reject'),
        ),
      ],
    ),
  );
}
