import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../homework_models.dart';

/// Homework list row with submission status and optional submit action.
class HomeworkListRow extends StatelessWidget {
  const HomeworkListRow({
    super.key,
    required this.item,
    this.onSubmit,
  });

  final StudentHomeworkItem item;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final statusStyle = _statusStyle(context, item.status);

    return Semantics(
      container: true,
      label:
          '${item.subject}, ${item.title}, ${item.status.label}${item.hasAttachment ? ', has attachment' : ''}',
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.subject,
                      style: text.labelMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  AksharaStatusChip(
                    label: statusStyle.label,
                    background: statusStyle.background,
                    foreground: statusStyle.foreground,
                    size: AksharaStatusChipSize.compact,
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                item.title,
                style: text.titleSmall.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                item.submittedLabel ?? item.dueLabel,
                style: text.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (item.hasAttachment) ...[
                const SizedBox(height: AksharaSpacing.s2),
                Row(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AksharaSpacing.s1),
                    Expanded(
                      child: Text(
                        item.attachmentLabel!,
                        style: text.labelSmall.copyWith(color: colors.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (onSubmit != null &&
                  item.status == StudentHomeworkStatus.pending) ...[
                const SizedBox(height: AksharaSpacing.s3),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: onSubmit,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ({String label, Color background, Color foreground}) _statusStyle(
    BuildContext context,
    StudentHomeworkStatus status,
  ) {
    final colors = context.colors;
    final ext = context.akshara;

    return switch (status) {
      StudentHomeworkStatus.pending => (
          label: 'Pending',
          background: colors.primaryContainer,
          foreground: colors.primary,
        ),
      StudentHomeworkStatus.submitted => (
          label: 'Submitted',
          background: ext.successContainer,
          foreground: ext.success,
        ),
      StudentHomeworkStatus.overdue => (
          label: 'Overdue',
          background: ext.warningContainer,
          foreground: ext.warning,
        ),
    };
  }
}
