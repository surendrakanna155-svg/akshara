import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../parent/attendance/attendance_calendar.dart';
import '../../parent/attendance/attendance_kpi_strip.dart';
import '../../parent/attendance/attendance_models.dart';
import '../../parent/attendance/attendance_month_selector.dart';
import '../../parent/attendance/attendance_summary_card.dart';
import 'student_attendance_provider.dart';
import '../../../theme/breakpoints.dart';

/// Student monthly attendance — ST-02.
class StudentAttendanceScreen extends ConsumerStatefulWidget {
  const StudentAttendanceScreen({super.key, this.onNotificationsTap});

  final VoidCallback? onNotificationsTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;
  @override
  ConsumerState<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState
    extends ConsumerState<StudentAttendanceScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _bannerKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studentAttendanceFutureProvider);
    final isLoading =
        ref.watch(studentAttendanceLoadingProvider) || async.isLoading;
    final hasError =
        ref.watch(studentAttendanceErrorProvider) || async.hasError;

    if (isLoading) {
      return Scaffold(
        backgroundColor: context.colors.surfaceContainerLow,
        appBar: _buildAppBar(context, subtitle: null, unread: 0),
        body: const AksharaLoadingState(semanticLabel: 'Loading attendance'),
      );
    }

    if (hasError) {
      return Scaffold(
        backgroundColor: context.colors.surfaceContainerLow,
        appBar: _buildAppBar(context, subtitle: null, unread: 0),
        body: AksharaErrorState(
          message: 'Unable to load your attendance right now.',
          onRetry: () {
            ref.read(studentAttendanceErrorProvider.notifier).state = false;
            ref.invalidate(studentAttendanceFutureProvider);
          },
        ),
      );
    }

    final data = ref.watch(studentAttendanceProvider);
    final insight = ref.watch(studentAttendanceInsightProvider);
    final highlightAbsent = ref.watch(studentAttendanceHighlightAbsentProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: _buildAppBar(
        context,
        subtitle: async.hasValue
            ? '${data.childName} · ${data.childClass}'
            : null,
        unread: async.hasValue ? data.unreadNotifications : 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >=
              StudentAttendanceScreen._tabletBreakpoint;
          final horizontalPadding = isTablet
              ? AksharaSpacing.tabletMargin
              : AksharaSpacing.mobileMargin;
          const cellSize = 36.0;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet
                    ? StudentAttendanceScreen._tabletMaxContentWidth
                    : double.infinity,
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AksharaSpacing.s4,
                  horizontalPadding,
                  AksharaSpacing.s6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AttendanceMonthSelector(
                      monthLabel: data.monthLabel,
                      onPrevious: () => _changeMonth(-1),
                      onNext: () => _changeMonth(1),
                    ),
                    const SizedBox(height: AksharaSpacing.s4),
                    AttendanceKpiStrip(
                      metrics: data.kpi,
                      onAbsentTap: _onAbsentKpiTap,
                    ),
                    const SizedBox(height: AksharaSpacing.s4),
                    SizedBox(
                      height: AttendanceCalendar.cardHeight,
                      child: AttendanceCalendar(
                        days: data.calendarDays,
                        cellSize: cellSize,
                        highlightAbsent: highlightAbsent,
                        onDayTap: _onCalendarDayTap,
                      ),
                    ),
                    if (data.warningBannerMessage != null) ...[
                      const SizedBox(height: AksharaSpacing.s4),
                      AksharaWarningBanner(
                        key: _bannerKey,
                        message: data.warningBannerMessage!,
                      ),
                    ],
                    const SizedBox(height: AksharaSpacing.s4),
                    const AksharaSectionHeader(
                      title: 'Attendance history',
                      fixedHeight: false,
                      spacingBelow: AksharaSpacing.s2,
                    ),
                    if (data.recentLogs.isEmpty)
                      const AksharaEmptyState(
                        message: 'No attendance records for this month.',
                        icon: Icons.event_busy_outlined,
                        compact: true,
                      )
                    else
                      Column(
                        children: [
                          for (var i = 0; i < data.recentLogs.length; i++) ...[
                            AttendanceSummaryCard(
                              log: data.recentLogs[i],
                              onInfoTap: () => _showDayDetailSheet(
                                context,
                                data.recentLogs[i],
                              ),
                            ),
                            if (i < data.recentLogs.length - 1)
                              const SizedBox(height: AksharaSpacing.s2),
                          ],
                        ],
                      ),
                    const SizedBox(height: AksharaSpacing.s4),
                    AksharaInsightCard(
                      message: insight.message,
                      actionLabel: insight.actionLabel,
                      icon: Icons.insights_outlined,
                      semanticLabelPrefix: 'AI attendance insight',
                      onAction: _onAbsentKpiTap,
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

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    required String? subtitle,
    required int unread,
  }) {
    return AksharaAppBar(
      titleText: 'Attendance',
      subtitle: subtitle,
      unreadNotifications: unread,
      showAi: true,
      trailingPadding: true,
      onNotificationsTap: widget.onNotificationsTap,
    );
  }

  void _changeMonth(int delta) {
    final current = ref.read(studentAttendanceMonthProvider);
    ref.read(studentAttendanceMonthProvider.notifier).state =
        DateTime(current.year, current.month + delta, 1);
    ref.read(studentAttendanceSelectedDayProvider.notifier).state = null;
    ref.read(studentAttendanceHighlightAbsentProvider.notifier).state = false;
  }

  void _onCalendarDayTap(AttendanceCalendarDay day) {
    if (day.date == null) return;
    ref.read(studentAttendanceSelectedDayProvider.notifier).state = day.date;
    _showDayDetailSheet(
      context,
      AttendanceDayLog(
        date: day.date!,
        status: day.status,
        detail: day.markedAt?.isNotEmpty == true
            ? 'Marked ${day.markedAt}'
            : _defaultDetail(day.status),
        detailTitle: day.detailTitle ?? '',
        detailBody: day.detailBody ?? '',
        detailNote: day.detailNote,
      ),
    );
  }

  void _onAbsentKpiTap() {
    ref.read(studentAttendanceHighlightAbsentProvider.notifier).state = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _bannerKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  String _defaultDetail(AttendanceDayStatus status) {
    return switch (status) {
      AttendanceDayStatus.present => 'Present for all sessions',
      AttendanceDayStatus.absent => 'Marked absent',
      AttendanceDayStatus.late => 'Late arrival recorded',
      AttendanceDayStatus.holiday => 'School holiday',
      _ => 'No record',
    };
  }

  void _showDayDetailSheet(BuildContext context, AttendanceDayLog log) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AksharaSpacing.s4,
          AksharaSpacing.s0,
          AksharaSpacing.s4,
          AksharaSpacing.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              log.detailTitle.isNotEmpty
                  ? log.detailTitle
                  : '${log.date.day} ${_monthName(log.date.month)}',
              style: context.aksharaText.titleMedium,
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Text(log.detail, style: context.aksharaText.bodyMedium),
            if (log.detailBody.isNotEmpty) ...[
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                log.detailBody,
                style: context.aksharaText.bodySmall.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}
