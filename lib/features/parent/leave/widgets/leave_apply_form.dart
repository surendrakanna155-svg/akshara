import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/qa_test_keys.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../leave_models.dart';
import '../parent_leave_provider.dart';

/// Apply-leave form for PA-12.
class LeaveApplyForm extends ConsumerWidget {
  const LeaveApplyForm({
    super.key,
    required this.onSubmit,
    this.isSubmitting = false,
  });

  final Future<void> Function() onSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(leaveApplyDraftProvider);
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Apply leave form',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<LeaveType>(
            initialValue: draft.type,
            decoration: const InputDecoration(
              labelText: 'Leave type',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final type in LeaveType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                ),
            ],
            onChanged: isSubmitting
                ? null
                : (value) {
                    if (value != null) {
                      ref.read(leaveApplyDraftProvider.notifier).state =
                          draft.copyWith(type: value);
                    }
                  },
          ),
          const SizedBox(height: AksharaSpacing.s3),
          TextFormField(
            initialValue: draft.fromDateLabel,
            readOnly: isSubmitting,
            decoration: const InputDecoration(
              labelText: 'From date',
              hintText: 'e.g. 12 Jun 2026',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            onChanged: (value) => ref
                .read(leaveApplyDraftProvider.notifier)
                .state = draft.copyWith(fromDateLabel: value),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          TextFormField(
            initialValue: draft.toDateLabel,
            readOnly: isSubmitting,
            decoration: const InputDecoration(
              labelText: 'To date',
              hintText: 'e.g. 13 Jun 2026',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            onChanged: (value) => ref
                .read(leaveApplyDraftProvider.notifier)
                .state = draft.copyWith(toDateLabel: value),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          TextFormField(
            initialValue: draft.reason,
            readOnly: isSubmitting,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Describe why leave is needed (min 8 characters)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            onChanged: (value) => ref
                .read(leaveApplyDraftProvider.notifier)
                .state = draft.copyWith(reason: value),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          // PAR-3 — medical-cert attachment REFERENCE (HWK-7 pattern: a file
          // name / label, since a real parent storage bucket is deferred). The
          // parent enters the document's name; on submit it is sent to the
          // leave and, once the leave exists, to attachLeaveDocument.
          OutlinedButton.icon(
            key: QaTestKeys.parentLeaveAttachmentButton,
            onPressed: isSubmitting
                ? null
                : () => _promptAttachmentReference(context, ref, draft),
            icon: const Icon(Icons.attach_file_outlined),
            label: Text(
              draft.hasAttachment
                  ? (draft.attachmentName ?? 'Attachment added')
                  : 'Add medical certificate (optional)',
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          if (!draft.isValid)
            Text(
              'Enter dates and a reason of at least 8 characters.',
              style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
          const SizedBox(height: AksharaSpacing.s2),
          FilledButton(
            onPressed: !draft.isValid || isSubmitting ? null : onSubmit,
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit leave request'),
          ),
        ],
      ),
    );
  }

  /// PAR-3 — collects an attachment REFERENCE (a file name / label). No real
  /// upload: the reference is persisted on the leave (HWK-7 pattern) so the
  /// school/HR side sees a medical certificate was cited; wiring a real parent
  /// storage bucket is the documented residual.
  Future<void> _promptAttachmentReference(
    BuildContext context,
    WidgetRef ref,
    LeaveApplyDraft draft,
  ) async {
    final controller = TextEditingController(text: draft.attachmentName ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Medical certificate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the document name / label to attach as a reference.',
              ),
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
            if (draft.hasAttachment)
              TextButton(
                onPressed: () => Navigator.of(context).pop(''),
                child: const Text('Remove'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: QaTestKeys.parentLeaveAttachmentConfirmButton,
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Attach'),
            ),
          ],
        );
      },
    );

    // null = cancelled (no change); '' = remove; otherwise set the reference.
    if (result == null) return;
    final notifier = ref.read(leaveApplyDraftProvider.notifier);
    if (result.isEmpty) {
      notifier.state = draft.copyWith(hasAttachment: false, attachmentName: '');
      return;
    }
    notifier.state =
        draft.copyWith(hasAttachment: true, attachmentName: result);
  }
}
