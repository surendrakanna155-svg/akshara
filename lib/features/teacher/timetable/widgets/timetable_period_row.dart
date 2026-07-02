import 'package:flutter/material.dart';

import '../../../../shared/semantic_status.dart';
import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../timetable_models.dart';

/// Teacher timetable period row with status pill.
class TimetablePeriodRow extends StatelessWidget {
  const TimetablePeriodRow({super.key, required this.period});

  final TeacherTimetablePeriod period;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final statusStyle = period.status.resolve(context);
    final statusIcon = switch (period.status) {
      ClassScheduleStatus.done => Icons.check_circle_outline,
      ClassScheduleStatus.now => Icons.play_circle_outline,
      ClassScheduleStatus.upcoming => Icons.schedule_outlined,
    };

    return Semantics(
      container: true,
      label:
          '${period.periodLabel}, ${period.subject} ${period.classLabel}, ${period.roomLabel}, ${statusStyle.label}',
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusStyle.background,
                  borderRadius: AksharaRadius.chip,
                ),
                child: Icon(
                  statusIcon,
                  size: 18,
                  color: statusStyle.foreground,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${period.periodLabel} · ${period.timeRange}',
                      style: text.labelMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      '${period.subject} · ${period.classLabel}',
                      style: text.titleSmall.copyWith(color: colors.onSurface),
                    ),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      period.roomLabel,
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    // TCH-4 — cover line: whose class this covers, or who is
                    // covering it, when a substitution applies to this period.
                    if (period.isCoveringForSomeone) ...[
                      const SizedBox(height: AksharaSpacing.s1),
                      Text(
                        'Covering ${period.coveringForTeacherName}',
                        style: text.bodySmall.copyWith(color: colors.tertiary),
                      ),
                    ] else if (period.isCovered) ...[
                      const SizedBox(height: AksharaSpacing.s1),
                      Text(
                        'Covered by ${period.substituteTeacherName ?? 'substitute'}',
                        style: text.bodySmall.copyWith(color: colors.tertiary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AksharaSpacing.s2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AksharaStatusChip(
                    label: statusStyle.label,
                    background: statusStyle.background,
                    foreground: statusStyle.foreground,
                    size: AksharaStatusChipSize.compact,
                  ),
                  if (period.isCovered || period.isCoveringForSomeone) ...[
                    const SizedBox(height: AksharaSpacing.s1),
                    AksharaStatusChip(
                      label: period.isCoveringForSomeone ? 'Cover' : 'Substitute',
                      tone: KpiAccent.warning,
                      size: AksharaStatusChipSize.compact,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
