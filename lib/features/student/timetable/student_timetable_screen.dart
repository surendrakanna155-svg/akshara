import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../parent/timetable/widgets/day_selector_strip.dart';
import '../../parent/timetable/widgets/timetable_period_row.dart';
import 'student_timetable_provider.dart';

/// Student weekly timetable — ST-03.
class StudentTimetableScreen extends ConsumerWidget {
  const StudentTimetableScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(studentTimetableProvider);
    final isLoading = ref.watch(studentTimetableLoadingProvider);
    final hasError = ref.watch(studentTimetableErrorProvider);
    final isEmpty = ref.watch(studentTimetableEmptyProvider);
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
        (true, _, _) =>
          const AksharaLoadingState(semanticLabel: 'Loading timetable'),
        (_, true, _) => AksharaErrorState(
            message: 'Unable to load timetable. Please try again.',
            onRetry: () =>
                ref.read(studentTimetableErrorProvider.notifier).state = false,
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
                    maxWidth:
                        isTablet ? _tabletMaxContentWidth : double.infinity,
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
                        SizedBox(
                          height: 88,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: AksharaKpiCard(
                                  value: '${data.totalPeriodsThisWeek}',
                                  subtitle: 'Periods this week',
                                  accent: KpiAccent.primary,
                                ),
                              ),
                              const SizedBox(width: AksharaSpacing.s2),
                              Expanded(
                                child: AksharaKpiCard(
                                  value: '${data.upcomingPeriodsToday}',
                                  subtitle: 'Upcoming today',
                                  accent: KpiAccent.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (data.scheduleChangeMessage != null) ...[
                          const SizedBox(height: AksharaSpacing.s3),
                          AksharaWarningBanner(
                            message: data.scheduleChangeMessage!,
                          ),
                        ],
                        const SizedBox(height: AksharaSpacing.s4),
                        DaySelectorStrip(
                          days: data.days,
                          onDayTap: (dayId) => ref
                              .read(studentTimetableSelectedDayProvider.notifier)
                              .state = dayId,
                        ),
                        const SizedBox(height: AksharaSpacing.s4),
                        AksharaSectionHeader(
                          title: selectedDay?.fullLabel ?? 'Schedule',
                          fixedHeight: false,
                          spacingBelow: AksharaSpacing.s3,
                        ),
                        if (selectedDay == null || selectedDay.periods.isEmpty)
                          const AksharaEmptyState(
                            message: 'No classes scheduled for this day.',
                            icon: Icons.event_available_outlined,
                            compact: true,
                          )
                        else
                          Column(
                            children: [
                              for (var i = 0;
                                  i < selectedDay.periods.length;
                                  i++) ...[
                                TimetablePeriodRow(
                                  period: selectedDay.periods[i],
                                ),
                                if (i < selectedDay.periods.length - 1)
                                  const SizedBox(
                                    height: AksharaSpacing.s3,
                                  ),
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
