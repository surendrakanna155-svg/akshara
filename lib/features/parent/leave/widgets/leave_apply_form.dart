import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          OutlinedButton.icon(
            onPressed: isSubmitting
                ? null
                : () {
                    ref.read(leaveApplyDraftProvider.notifier).state =
                        draft.copyWith(
                      hasAttachment: true,
                      attachmentName: 'supporting_document.pdf',
                    );
                  },
            icon: const Icon(Icons.attach_file_outlined),
            label: Text(
              draft.hasAttachment
                  ? (draft.attachmentName ?? 'Attachment added')
                  : 'Add attachment (optional)',
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
}
