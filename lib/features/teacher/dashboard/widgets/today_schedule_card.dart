import 'package:flutter/material.dart';

import '../../../../shared/semantic_status.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../teacher_dashboard_provider.dart';

/// TA-01 today's classes section with [ScheduleClass] rows.
class TodayScheduleCard extends StatelessWidget {
  const TodayScheduleCard({
    super.key,
    required this.classes,
    this.onTimetableTap,
    this.onClassTap,
  });

  final List<ScheduleClass> classes;
  final VoidCallback? onTimetableTap;
  final void Function(ScheduleClass scheduleClass)? onClassTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: "Today's classes, ${classes.length} scheduled",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AksharaSectionHeader(
            title: "Today's Classes",
            trailingLabel: 'Timetable',
            onTrailingTap: onTimetableTap,
            fixedHeight: false,
            spacingBelow: AksharaSpacing.s3,
            trailingStyle: AksharaSectionHeaderTrailingStyle.compact,
          ),
          if (classes.isEmpty)
            AksharaSectionEmpty(
              message: 'No classes scheduled for today.',
              icon: Icons.event_busy_outlined,
              actionLabel: onTimetableTap != null ? 'Timetable' : null,
              onAction: onTimetableTap,
            )
          else
            for (var i = 0; i < classes.length; i++) ...[
            if (i > 0) const SizedBox(height: AksharaSpacing.s2),
            _ClassScheduleRow(
              scheduleClass: classes[i],
              onTap: onClassTap == null
                  ? null
                  : () => onClassTap!(classes[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassScheduleRow extends StatelessWidget {
  const _ClassScheduleRow({
    required this.scheduleClass,
    this.onTap,
  });

  final ScheduleClass scheduleClass;
  final VoidCallback? onTap;

  static const double rowHeight = 72;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final statusColors = scheduleClass.status.resolve(context);

    return Semantics(
      button: onTap != null,
      label:
          '${scheduleClass.timeLabel}, ${scheduleClass.subject} ${scheduleClass.classLabel}, '
          '${scheduleClass.room}, ${statusColors.label}',
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: rowHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AksharaSpacing.s3,
                vertical: AksharaSpacing.s2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      scheduleClass.timeLabel,
                      style: text.labelMedium.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${scheduleClass.subject} · ${scheduleClass.classLabel}',
                          style: text.bodyLarge.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scheduleClass.room,
                          style: text.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s2),
                  Flexible(
                    child: AksharaStatusChip(
                      label: statusColors.label,
                      background: statusColors.background,
                      foreground: statusColors.foreground,
                      size: AksharaStatusChipSize.compact,
                      fontWeight: FontWeight.w600,
                    ),
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
