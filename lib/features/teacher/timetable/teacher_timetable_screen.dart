import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../parent/timetable/timetable_models.dart';
import '../../parent/timetable/widgets/day_selector_strip.dart';
import 'teacher_timetable_provider.dart';
import 'widgets/timetable_period_row.dart';

/// Teacher weekly timetable — TA-03.
class TeacherTimetableScreen extends ConsumerWidget {
  const TeacherTimetableScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(teacherTimetableProvider);
    final isLoading = ref.watch(teacherTimetableLoadingProvider);
    final hasError = ref.watch(teacherTimetableErrorProvider);
    final selectedDay = data.selectedDay;

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Timetable',
        subtitle: data.weekRangeLabel,
        unreadNotifications: data.unreadNotifications,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load timetable.',
                  onRetry: () => ref
                      .read(teacherTimetableErrorProvider.notifier)
                      .state = false,
                )
              : data.days.isEmpty
                  ? const AksharaEmptyState(
                      message: 'No timetable available.',
                      icon: Icons.calendar_view_week_outlined,
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isTablet =
                            constraints.maxWidth >= _tabletBreakpoint;
                        final pad = isTablet
                            ? AksharaSpacing.tabletMargin
                            : AksharaSpacing.mobileMargin;

                        return Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isTablet
                                  ? _tabletMaxContentWidth
                                  : double.infinity,
                            ),
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                pad,
                                AksharaSpacing.s4,
                                pad,
                                AksharaSpacing.s6,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DaySelectorStrip(
                                    days: data.days
                                        .map(
                                          (d) => TimetableDay(
                                            id: d.id,
                                            shortLabel: d.shortLabel,
                                            fullLabel: d.fullLabel,
                                            date: DateTime(2026, 6, 1),
                                            periods: const [],
                                            isSelected: d.isSelected,
                                            isToday: d.isToday,
                                          ),
                                        )
                                        .toList(),
                                    onDayTap: (id) => ref
                                        .read(
                                          teacherTimetableDayProvider.notifier,
                                        )
                                        .state = id,
                                  ),
                                  const SizedBox(height: AksharaSpacing.s4),
                                  AksharaSectionHeader(
                                    title: selectedDay == null
                                        ? 'Periods'
                                        : '${selectedDay.fullLabel} Periods',
                                    fixedHeight: false,
                                  ),
                                  const SizedBox(height: AksharaSpacing.s3),
                                  if (selectedDay == null ||
                                      selectedDay.periods.isEmpty)
                                    const AksharaEmptyState(
                                      message: 'No periods scheduled.',
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
    );
  }
}
