import 'package:flutter/material.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/premium_tokens.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../../theme/typography.dart';
import 'attendance_models.dart';

/// PA-02 attendance summary — DS V2 Phase 3/4 flagship: the month attendance %
/// as a signature persona-accent progress **ring**, with absent-days (tappable)
/// and late-days as adjacent stats. Same three metrics as the old three-up KPI
/// strip; the absent tap (highlight + scroll) is preserved.
class AttendanceKpiStrip extends StatelessWidget {
  const AttendanceKpiStrip({
    super.key,
    required this.metrics,
    this.onAbsentTap,
  });

  final AttendanceKpiMetrics metrics;
  final VoidCallback? onAbsentTap;

  @override
  Widget build(BuildContext context) {
    final premium = context.premium;
    final text = context.aksharaText;
    final colors = context.colors;
    final ext = context.akshara;

    return Semantics(
      container: true,
      label: 'Attendance ${metrics.attendancePercent} percent this month, '
          '${metrics.absentDays} absent, ${metrics.lateDays} late',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: premium.premiumSurface,
          borderRadius: BorderRadius.circular(AksharaRadius.xl),
          border: Border.all(color: premium.premiumBorder),
          boxShadow: premium.softShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AksharaProgressRing(
                value: metrics.attendancePercent / 100.0,
                size: 92,
                strokeWidth: 9,
                color: premium.brandStart,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${metrics.attendancePercent}%',
                      style: text.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'This month',
                      style: text.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AksharaSpacing.s5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Stat(
                      value: '${metrics.absentDays}',
                      label: 'Absent days',
                      color: colors.error,
                      onTap: onAbsentTap,
                    ),
                    const SizedBox(height: AksharaSpacing.s3),
                    _Stat(
                      value: '${metrics.lateDays}',
                      label: 'Late',
                      color: ext.warning,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: text.titleLarge
              .copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.05,
              )
              .tabularFigures,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AksharaRadius.sm),
        child: content,
      ),
    );
  }
}
