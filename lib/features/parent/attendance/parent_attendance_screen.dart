import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../core/widgets/whatsapp_contact_button.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../academics/widgets/academics_shortcuts_strip.dart';
import 'attendance_calendar.dart';
import 'attendance_kpi_strip.dart';
import 'attendance_models.dart';
import 'attendance_month_selector.dart';
import 'attendance_summary_card.dart';
import 'parent_attendance_provider.dart';
import 'parent_attendance_workflow.dart';
import '../../../theme/breakpoints.dart';

/// Parent attendance — PA-02 `PA-02-ParentAttendance-M`.
class ParentAttendanceScreen extends ConsumerStatefulWidget {
  const ParentAttendanceScreen({
    super.key,
    this.onNotificationsTap,
    this.onAcademicsNavigate,
  });

  final VoidCallback? onNotificationsTap;
  final void Function(String destination)? onAcademicsNavigate;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;
  static const double _largeMobileBreakpoint = AksharaBreakpoints.largeMobileMinWidth;

  @override
  ConsumerState<ParentAttendanceScreen> createState() =>
      _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends ConsumerState<ParentAttendanceScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _bannerKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(parentAttendanceProvider);
    final isLoading = ref.watch(parentAttendanceLoadingProvider);
    final hasError = ref.watch(parentAttendanceErrorProvider);
    final highlightAbsent = ref.watch(attendanceHighlightAbsentProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Attendance',
        subtitle: '${data.childName} · ${data.childClass}',
        unreadNotifications: data.unreadNotifications,
        showAi: false,
        trailingPadding: true,
        onNotificationsTap: widget.onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load attendance right now.',
                  onRetry: () =>
                      ref.read(parentAttendanceErrorProvider.notifier).state = false,
                )
              : LayoutBuilder(
              builder: (context, constraints) {
                final isTablet =
                    constraints.maxWidth >= ParentAttendanceScreen._tabletBreakpoint;
                final isLargeMobile = constraints.maxWidth >=
                    ParentAttendanceScreen._largeMobileBreakpoint;
                final horizontalPadding = isTablet
                    ? AksharaSpacing.tabletMargin
                    : AksharaSpacing.mobileMargin;
                final cellSize = isLargeMobile ? 52.0 : 48.0;

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet
                          ? ParentAttendanceScreen._tabletMaxContentWidth
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
                          AcademicsShortcutsStrip(
                            onTimetableTap: () =>
                                widget.onAcademicsNavigate?.call('timetable'),
                            onHomeworkTap: () =>
                                widget.onAcademicsNavigate?.call('homework'),
                            onExamsTap: () =>
                                widget.onAcademicsNavigate?.call('exams'),
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
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
                            title: 'Recent',
                            fixedHeight: false,
                            spacingBelow: AksharaSpacing.s2,
                          ),
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
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _changeMonth(int delta) {
    final current = ref.read(attendanceMonthProvider);
    final next = DateTime(current.year, current.month + delta, 1);
    ref.read(attendanceMonthProvider.notifier).state = next;
    ref.read(attendanceSelectedDayProvider.notifier).state = null;
    ref.read(attendanceHighlightAbsentProvider.notifier).state = false;
  }

  void _onCalendarDayTap(AttendanceCalendarDay day) {
    if (day.date == null) {
      return;
    }
    ref.read(attendanceSelectedDayProvider.notifier).state = day.date;
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
    ref.read(attendanceHighlightAbsentProvider.notifier).state = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _bannerKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  String _defaultDetail(AttendanceDayStatus status) {
    return switch (status) {
      AttendanceDayStatus.present => 'Marked on time',
      AttendanceDayStatus.absent => 'No mark by 10:00 AM',
      AttendanceDayStatus.late => 'Marked late',
      AttendanceDayStatus.holiday => 'Holiday',
      _ => '',
    };
  }

  void _showDayDetailSheet(BuildContext context, AttendanceDayLog log) {
    final attendance = ref.read(parentAttendanceProvider);
    final teacherPhone = attendance.classTeacherPhone;
    final hostContext = context;
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DayDetailSheet(
        log: log,
        hostContext: hostContext,
        scaffoldMessenger: messenger,
        classTeacherPhone: teacherPhone,
        childName: attendance.childName,
        childClass: attendance.childClass,
      ),
    );
  }
}

class _DayDetailSheet extends ConsumerWidget {
  const _DayDetailSheet({
    required this.log,
    required this.hostContext,
    required this.scaffoldMessenger,
    required this.childName,
    required this.childClass,
    this.classTeacherPhone,
  });

  final AttendanceDayLog log;
  final BuildContext hostContext;
  final ScaffoldMessengerState scaffoldMessenger;
  final String childName;
  final String childClass;
  final String? classTeacherPhone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;
    final statusStyle = log.status.resolve(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AksharaSpacing.s4,
        right: AksharaSpacing.s4,
        bottom: MediaQuery.paddingOf(context).bottom + AksharaSpacing.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            log.detailTitle,
            style: text.titleMedium.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: AksharaStatusChip(
              label: statusStyle.label,
              background: statusStyle.background,
              foreground: statusStyle.foreground,
              size: AksharaStatusChipSize.standard,
            ),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          Text(
            log.detailBody,
            style: text.bodyLarge.copyWith(color: colors.onSurface),
          ),
          if (log.status == AttendanceDayStatus.absent) ...[
            const SizedBox(height: AksharaSpacing.s4),
            OutlinedButton.icon(
              key: QaTestKeys.parentAttendanceCorrectionButton,
              onPressed: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!hostContext.mounted) return;
                  showParentAttendanceCorrectionDialog(
                    hostContext,
                    ref,
                    scaffoldMessenger: scaffoldMessenger,
                    log: log,
                    childName: childName,
                    childClass: childClass,
                  );
                });
              },
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Request correction'),
            ),
          ],
          if (log.detailNote != null) ...[
            const SizedBox(height: AksharaSpacing.s4),
            Text(
              log.detailNote!,
              style: text.bodySmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Align(
              alignment: Alignment.centerLeft,
              child: WhatsAppContactButton(
                phone: classTeacherPhone,
                label: 'Contact class teacher via WhatsApp',
                style: WhatsAppButtonStyle.text,
                message:
                    'Hello, I would like to discuss attendance for ${log.detailTitle}.',
                unavailableMessage: 'Class teacher contact is unavailable.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
