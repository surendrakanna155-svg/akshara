import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../homework_models.dart';

/// Fixed-height homework list row.
class HomeworkListRow extends StatelessWidget {
  const HomeworkListRow({
    super.key,
    required this.item,
    this.onTap,
  });

  final ParentHomeworkItem item;
  final VoidCallback? onTap;

  static const double rowHeight = 80;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      button: onTap != null,
      label: '${item.subject}: ${item.title}. ${item.status.label}',
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AksharaRadius.card,
          child: SizedBox(
            height: rowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AksharaSpacing.s3,
                vertical: AksharaSpacing.s2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.subject,
                          style: text.labelSmall.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AksharaSpacing.s1),
                        Text(
                          item.title,
                          style: text.bodyMedium.copyWith(
                            color: colors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AksharaSpacing.s1),
                        Text(
                          item.dueLabel,
                          style: text.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.isReviewed) ...[
                          const SizedBox(height: AksharaSpacing.s1),
                          Text(
                            'Grade ${item.reviewGrade}'
                            '${(item.reviewComment ?? '').isNotEmpty ? ' — ${item.reviewComment}' : ''}',
                            style: text.bodySmall.copyWith(color: colors.primary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s2),
                  AksharaStatusChip(
                    label: item.status.label,
                    tone: _toneForStatus(item.status),
                    size: AksharaStatusChipSize.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  KpiAccent _toneForStatus(ParentHomeworkStatus status) {
    return switch (status) {
      ParentHomeworkStatus.pending => KpiAccent.warning,
      ParentHomeworkStatus.submitted => KpiAccent.success,
      ParentHomeworkStatus.reviewed => KpiAccent.primary,
      ParentHomeworkStatus.overdue => KpiAccent.error,
    };
  }
}
