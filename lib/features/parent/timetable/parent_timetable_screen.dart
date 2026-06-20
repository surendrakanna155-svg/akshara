import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'parent_timetable_provider.dart';
import 'widgets/day_selector_strip.dart';
import 'widgets/timetable_period_row.dart';
import '../../../theme/breakpoints.dart';

/// Parent timetable — PA-04.
class ParentTimetableScreen extends ConsumerWidget {
  const ParentTimetableScreen({
    super.key,
    this.onNotificationsTap,
  });

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(parentTimetableProvider);
    final isLoading = ref.watch(parentTimetableLoadingProvider);
    final hasError = ref.watch(parentTimetableErrorProvider);
    final isEmpty = ref.watch(parentTimetableEmptyProvider);
    final selectedDay = data.selectedDay;

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Timetable',
        subtitle: '${data.childName} · ${data.childClass}',
        unreadNotifications: data.unreadNotifications,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: switch ((isLoading, hasError, isEmpty)) {
        (true, _, _) => const AksharaLoadingState(semanticLabel: 'Loading timetable'),
        (_, true, _) => AksharaErrorState(
            message: 'Unable to load timetable. Please try again.',
            onRetry: () {
              ref.read(parentTimetableErrorProvider.notifier).state = false;
            },
          ),
        (_, _, true) => const AksharaEmptyState(
            message: 'No timetable is available for this week.',
            icon: Icons.calendar_today_outlined,
          ),
        _ => LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= _tabletBreakpoint;
              final horizontalPadding = isTablet
                  ? AksharaSpacing.tabletMargin
                  : AksharaSpacing.mobileMargin;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? _tabletMaxContentWidth : double.infinity,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AksharaSpacing.s4,
                      horizontalPadding,
                      AksharaSpacing.s6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          container: true,
                          label: 'Week ${data.weekRangeLabel}',
                          child: Text(
                            data.weekRangeLabel,
                            style: context.aksharaText.labelLarge.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: AksharaSpacing.s3),
                        Row(
                          children: [
                            Expanded(
                              child: AksharaKpiCard(
                                value: '${data.totalPeriodsThisWeek}',
                                subtitle: 'This week',
                                accent: KpiAccent.primary,
                                style: AksharaKpiCardStyle.filled,
                                semanticLabel:
                                    '${data.totalPeriodsThisWeek} periods this week',
                              ),
                            ),
                            const SizedBox(width: AksharaSpacing.s2),
                            Expanded(
                              child: AksharaKpiCard(
                                value: '${data.completedPeriodsToday}',
                                subtitle: 'Done today',
                                accent: KpiAccent.success,
                                style: AksharaKpiCardStyle.filled,
                                semanticLabel:
                                    '${data.completedPeriodsToday} periods done today',
                              ),
                            ),
                            const SizedBox(width: AksharaSpacing.s2),
                            Expanded(
                              child: AksharaKpiCard(
                                value: '${data.upcomingPeriodsToday}',
                                subtitle: 'Upcoming',
                                accent: KpiAccent.warning,
                                style: AksharaKpiCardStyle.filled,
                                semanticLabel:
                                    '${data.upcomingPeriodsToday} upcoming periods today',
                              ),
                            ),
                          ],
                        ),
                        if (data.scheduleChangeMessage != null) ...[
                          const SizedBox(height: AksharaSpacing.s4),
                          AksharaWarningBanner(
                            message: data.scheduleChangeMessage!,
                            semanticLabel:
                                'Schedule change. ${data.scheduleChangeMessage!}',
                          ),
                        ],
                        const SizedBox(height: AksharaSpacing.s4),
                        const AksharaSectionHeader(
                          title: 'School Week',
                          fixedHeight: false,
                          spacingBelow: AksharaSpacing.s2,
                        ),
                        DaySelectorStrip(
                          days: data.days,
                          onDayTap: (dayId) {
                            ref.read(parentTimetableSelectedDayProvider.notifier).state =
                                dayId;
                          },
                        ),
                        const SizedBox(height: AksharaSpacing.s4),
                        AksharaSectionHeader(
                          title: selectedDay == null
                              ? 'Today\'s Periods'
                              : '${selectedDay.fullLabel} Periods',
                          fixedHeight: false,
                          spacingBelow: AksharaSpacing.s2,
                        ),
                        if (selectedDay == null || selectedDay.periods.isEmpty)
                          const AksharaEmptyState(
                            message: 'No periods scheduled for this day.',
                            compact: true,
                            icon: Icons.event_busy_outlined,
                          )
                        else
                          Column(
                            children: [
                              for (var i = 0; i < selectedDay.periods.length; i++) ...[
                                TimetablePeriodRow(period: selectedDay.periods[i]),
                                if (i < selectedDay.periods.length - 1)
                                  const SizedBox(height: AksharaSpacing.s2),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      },
    );
  }
}
