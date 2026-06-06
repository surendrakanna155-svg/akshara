import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../notices_models.dart';

/// Notice row with priority chip for ST-06.
class NoticeListRow extends StatelessWidget {
  const NoticeListRow({super.key, required this.notice});

  final StudentNotice notice;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final priorityStyle = _priorityStyle(context, notice.priority);

    return Semantics(
      container: true,
      label:
          '${notice.title}, ${notice.priority.label} priority, ${notice.dateLabel}',
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
                      notice.title,
                      style: text.titleSmall.copyWith(
                        color: colors.onSurface,
                        fontWeight:
                            notice.isRead ? FontWeight.w500 : FontWeight.w600,
                      ),
                    ),
                  ),
                  AksharaStatusChip(
                    label: priorityStyle.label,
                    background: priorityStyle.background,
                    foreground: priorityStyle.foreground,
                    size: AksharaStatusChipSize.compact,
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                '${notice.scope.label} · ${notice.dateLabel}',
                style: text.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                notice.summary,
                style: text.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({String label, Color background, Color foreground}) _priorityStyle(
    BuildContext context,
    StudentNoticePriority priority,
  ) {
    final colors = context.colors;
    final ext = context.akshara;

    return switch (priority) {
      StudentNoticePriority.normal => (
          label: 'Normal',
          background: colors.surfaceContainerLow,
          foreground: colors.onSurfaceVariant,
        ),
      StudentNoticePriority.important => (
          label: 'Important',
          background: colors.primaryContainer,
          foreground: colors.primary,
        ),
      StudentNoticePriority.urgent => (
          label: 'Urgent',
          background: ext.warningContainer,
          foreground: ext.warning,
        ),
    };
  }
}
