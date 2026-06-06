import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../timetable_models.dart';

/// Timetable list row showing period details and status.
class TimetablePeriodRow extends StatelessWidget {
  const TimetablePeriodRow({
    super.key,
    required this.period,
  });

  final TimetablePeriod period;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;
    final statusStyle = period.status.resolve(context);

    return Semantics(
      container: true,
      label:
          '${period.periodLabel}, ${period.subject}, ${period.timeRange}, ${statusStyle.label}',
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
                  statusStyle.icon,
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
                      period.subject,
                      style: text.titleSmall.copyWith(color: colors.onSurface),
                    ),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      '${period.teacherName} · ${period.roomLabel}',
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (period.isRoomChanged) ...[
                      const SizedBox(height: AksharaSpacing.s1),
                      Text(
                        'Room changed for this period',
                        style: text.labelSmall.copyWith(color: colors.error),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AksharaSpacing.s2),
              AksharaStatusChip(
                label: statusStyle.label,
                background: statusStyle.background,
                foreground: statusStyle.foreground,
                size: AksharaStatusChipSize.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
