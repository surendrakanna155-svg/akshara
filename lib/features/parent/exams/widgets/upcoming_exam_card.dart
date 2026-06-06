import 'package:flutter/material.dart';

import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../exam_models.dart';

/// Upcoming exam schedule card used by parent exams.
class UpcomingExamCard extends StatelessWidget {
  const UpcomingExamCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final ExamScheduleItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final ext = context.akshara;

    return Semantics(
      button: onTap != null,
      label: '${item.title}, ${item.dateLabel}, ${item.timeLabel}',
      child: Material(
        color: colors.surface,
        elevation: 1,
        shadowColor: colors.onSurface.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AksharaRadius.card,
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: text.titleSmall.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AksharaSpacing.s2,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ext.warningContainer,
                          borderRadius: BorderRadius.circular(
                            AksharaRadius.full,
                          ),
                        ),
                        child: Text(
                          'Today',
                          style: text.labelSmall.copyWith(color: ext.warning),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AksharaSpacing.s1),
                Text(
                  item.subject,
                  style:
                      text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: AksharaSpacing.s3),
                _MetaRow(
                    icon: Icons.calendar_today_outlined, text: item.dateLabel),
                const SizedBox(height: AksharaSpacing.s2),
                _MetaRow(icon: Icons.schedule, text: item.timeLabel),
                const SizedBox(height: AksharaSpacing.s2),
                _MetaRow(
                    icon: Icons.location_on_outlined, text: item.venueLabel),
                const SizedBox(height: AksharaSpacing.s2),
                _MetaRow(
                    icon: Icons.menu_book_outlined, text: item.syllabusLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.aksharaText;

    return Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: AksharaSpacing.s2),
        Expanded(
          child: Text(
            text,
            style:
                typography.bodySmall.copyWith(color: colors.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
