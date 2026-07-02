import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../parent/timetable/timetable_models.dart';
import '../../parent/timetable/widgets/day_selector_strip.dart';
import '../reports/teacher_report_exporters.dart';
import '../reports/teacher_report_share_sheet.dart';
import 'teacher_timetable_provider.dart';
import 'widgets/timetable_period_row.dart';
import '../../../theme/breakpoints.dart';

/// Teacher weekly timetable — TA-03.
class TeacherTimetableScreen extends ConsumerWidget {
  const TeacherTimetableScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;

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
        additionalActions: [
          // TCH-7 — share/export the weekly timetable (XCT-1 grid CSV/PDF).
          IconButton(
            key: QaTestKeys.teacherTimetableExportButton,
            tooltip: 'Export timetable',
            onPressed: data.days.isEmpty
                ? null
                : () {
                    final exporters = TeacherReportExporters(
                      ref.read(aksharaReportExportServiceProvider),
                    );
                    showTeacherExportSheet(
                      context,
                      title: 'Export weekly timetable',
                      onCsv: () => exporters.shareTimetableCsv(data),
                      onPdf: () => exporters.shareTimetablePdf(data),
                    );
                  },
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
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
                                            date: _dateForDayId(d.id),
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

/// TCH-9: resolves the real calendar date for a weekday chip (mon–sun) within
/// the current week, so the day selector shows correct, distinct dates instead
/// of a constant "1".
DateTime _dateForDayId(String id) {
  const weekdayByDayId = <String, int>{
    'mon': DateTime.monday,
    'tue': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'thu': DateTime.thursday,
    'fri': DateTime.friday,
    'sat': DateTime.saturday,
    'sun': DateTime.sunday,
  };
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final targetWeekday = weekdayByDayId[id.toLowerCase()] ?? today.weekday;
  return today.add(Duration(days: targetWeekday - today.weekday));
}
