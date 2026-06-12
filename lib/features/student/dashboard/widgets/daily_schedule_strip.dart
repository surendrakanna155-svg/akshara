import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../student_dashboard_provider.dart';

/// ST-01 horizontal timetable strip with [SchedulePeriod] pills.
class DailyScheduleStrip extends StatelessWidget {
  const DailyScheduleStrip({
    super.key,
    required this.periods,
    this.onFullScheduleTap,
    this.onPeriodTap,
    this.largeMobileBreakpoint = 428,
  });

  final List<SchedulePeriod> periods;
  final VoidCallback? onFullScheduleTap;
  final void Function(SchedulePeriod period)? onPeriodTap;
  final double largeMobileBreakpoint;

  static const double stripHeight = 120;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      container: true,
      label: "Today's schedule, ${periods.length} periods",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AksharaSectionHeader(
            title: 'Today',
            trailingLabel: 'Full schedule',
            onTrailingTap: onFullScheduleTap,
            fixedHeight: false,
            spacingBelow: AksharaSpacing.s3,
            trailingStyle: AksharaSectionHeaderTrailingStyle.compact,
          ),
          if (periods.isEmpty)
            AksharaSectionEmpty(
              message: 'No periods scheduled today.',
              icon: Icons.schedule_outlined,
              actionLabel: onFullScheduleTap != null ? 'Full schedule' : null,
              onAction: onFullScheduleTap,
            )
          else
            LayoutBuilder(
            builder: (context, constraints) {
              final pillWidth = constraints.maxWidth >= largeMobileBreakpoint
                  ? 108.0
                  : 100.0;

              return Material(
                color: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AksharaRadius.card,
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: SizedBox(
                  height: stripHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(AksharaSpacing.s3),
                    itemCount: periods.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AksharaSpacing.s2),
                    itemBuilder: (context, index) {
                      final period = periods[index];
                      return AksharaPeriodPill(
                        timeLabel: period.timeLabel,
                        subject: period.subject,
                        teacherName: period.teacherName,
                        state: period.state,
                        width: pillWidth,
                        onTap: onPeriodTap == null
                            ? null
                            : () => onPeriodTap!(period),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
