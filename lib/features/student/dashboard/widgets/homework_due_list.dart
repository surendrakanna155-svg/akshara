import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../student_dashboard_provider.dart';

/// ST-01 homework due section with [HomeworkDueItem] rows.
class HomeworkDueList extends StatelessWidget {
  const HomeworkDueList({
    super.key,
    required this.items,
    this.onSeeAllTap,
    this.onItemTap,
  });

  final List<HomeworkDueItem> items;
  final VoidCallback? onSeeAllTap;
  final void Function(HomeworkDueItem item)? onItemTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Homework due soon, ${items.length} assignments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AksharaSectionHeader(
            title: 'Due soon',
            trailingLabel: 'See all',
            onTrailingTap: onSeeAllTap,
            fixedHeight: false,
            spacingBelow: AksharaSpacing.s2,
            trailingStyle: AksharaSectionHeaderTrailingStyle.compact,
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: AksharaSpacing.s2),
            _HomeworkDueRow(
              item: items[i],
              onTap: onItemTap == null ? null : () => onItemTap!(items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeworkDueRow extends StatelessWidget {
  const _HomeworkDueRow({
    required this.item,
    this.onTap,
  });

  final HomeworkDueItem item;
  final VoidCallback? onTap;

  static const double rowHeight = 80;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final isOverdue = item.status == HomeworkStatus.overdue;

    return Semantics(
      button: onTap != null,
      label:
          '${item.title}, ${item.subject}, ${item.dueLabel}, '
          '${isOverdue ? 'Overdue' : 'Pending'}',
      child: Material(
        color: colors.surface,
        elevation: 0,
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
                vertical: AksharaSpacing.s4,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.icon,
                      size: 22,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.title,
                          style: text.bodyLarge.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.subject} · ${item.dueLabel}',
                          style: text.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  AksharaStatusChip(
                    label: isOverdue ? 'Overdue' : 'Pending',
                    tone: isOverdue ? KpiAccent.error : KpiAccent.warning,
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
}
