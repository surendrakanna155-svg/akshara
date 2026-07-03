import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_text.dart';
import '../../../../core/testing/qa_test_keys.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../parent_mutations_provider.dart';
import '../leave_models.dart';
import 'leave_status_chip.dart';
import 'leave_timeline.dart';

/// Expandable leave history row for PA-12.
///
/// A PENDING leave the parent submitted can be withdrawn (PAR-D1) or have a
/// medical-certificate reference attached (PAR-3); both are own-child + pending
/// only, enforced server-side. An already-decided leave shows neither action.
class LeaveRequestRow extends ConsumerWidget {
  const LeaveRequestRow({
    super.key,
    required this.request,
    this.initiallyExpanded = false,
  });

  final LeaveRequest request;
  final bool initiallyExpanded;

  bool get _isPending => request.status == LeaveStatus.pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label:
          '${request.type.label} leave ${request.fromDateLabel} to ${request.toDateLabel}, ${request.status.label}',
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AksharaSpacing.s4,
              vertical: AksharaSpacing.s1,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AksharaSpacing.s4,
              AksharaSpacing.s0,
              AksharaSpacing.s4,
              AksharaSpacing.s4,
            ),
            title: Text(
              '${request.fromDateLabel} – ${request.toDateLabel}',
              style: text.titleSmall.copyWith(color: colors.onSurface),
            ),
            subtitle: Text(
              '${request.type.label} · ${request.submittedLabel}',
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
            trailing: LeaveStatusChip(status: request.status),
            children: [
              Text(
                request.reason,
                style: text.bodyMedium.copyWith(color: colors.onSurface),
              ),
              if (request.hasAttachment) ...[
                const SizedBox(height: AksharaSpacing.s2),
                Row(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AksharaSpacing.s2),
                    Expanded(
                      child: Text(
                        request.attachmentName ?? 'Attachment added',
                        style: text.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AksharaSpacing.s3),
              LeaveTimeline(steps: request.timeline),
              if (_isPending) ...[
                const SizedBox(height: AksharaSpacing.s3),
                _PendingActions(request: request),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingActions extends ConsumerWidget {
  const _PendingActions({required this.request});

  final LeaveRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancelState = ref.watch(cancelParentLeaveProvider);
    final attachState = ref.watch(attachParentLeaveDocumentProvider);
    final busy = cancelState.isLoading || attachState.isLoading;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: QaTestKeys.parentLeaveAttachmentButton,
            onPressed: busy ? null : () => _attach(context, ref),
            icon: const Icon(Icons.attach_file_outlined, size: 18),
            label: Text(
              request.hasAttachment ? 'Update document' : 'Attach document',
            ),
          ),
        ),
        const SizedBox(width: AksharaSpacing.s3),
        Expanded(
          child: OutlinedButton.icon(
            key: QaTestKeys.parentLeaveCancelButton(request.id),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.error,
            ),
            onPressed: busy ? null : () => _cancel(context, ref),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Withdraw'),
          ),
        ),
      ],
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw leave request?'),
        content: const Text(
          'This will cancel the pending leave. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            key: QaTestKeys.parentLeaveCancelConfirmButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(cancelParentLeaveProvider.notifier).execute(request.id);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          key: QaTestKeys.parentLeaveCancelSnackbar,
          content: Text('Leave request withdrawn.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      // Surfaces the 409 "already decided" message verbatim, friendly.
      messenger.showSnackBar(
        SnackBar(
          key: QaTestKeys.parentLeaveCancelSnackbar,
          content: Text(aksharaErrorMessage(error)),
        ),
      );
    }
  }

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: request.attachmentName ?? '');
    final fileName = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attach medical certificate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the document name / label to attach.'),
            const SizedBox(height: AksharaSpacing.s3),
            TextField(
              key: QaTestKeys.parentLeaveAttachmentField,
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Document name',
                hintText: 'e.g. Dr Rao medical certificate.pdf',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: QaTestKeys.parentLeaveAttachmentConfirmButton,
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Attach'),
          ),
        ],
      ),
    );
    if (fileName == null || fileName.isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(attachParentLeaveDocumentProvider.notifier).execute(
            leaveId: request.id,
            fileName: fileName,
          );
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Attached: $fileName')),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(aksharaErrorMessage(error))),
      );
    }
  }
}
