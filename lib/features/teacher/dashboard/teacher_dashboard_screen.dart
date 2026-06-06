import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'teacher_dashboard_provider.dart';
import 'widgets/attendance_summary_card.dart';
import 'widgets/class_teacher_card.dart';
import 'widgets/greeting_header.dart';
import 'widgets/pending_tasks_section.dart';
import 'widgets/today_schedule_card.dart';

/// Teacher home dashboard — TA-01 `TA-01-TeacherDashboard-M`.
class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({
    super.key,
    this.onNavigate,
  });

  /// Route handler; receives action ids from TA-01 prototype map.
  final void Function(String actionId)? onNavigate;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(teacherDashboardProvider);
    final isLoading = ref.watch(teacherDashboardLoadingProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Dashboard',
        titleTrailing: AksharaContextChip(
          label: data.periodLabel,
          semanticLabel: 'Current period: ${data.periodLabel}',
        ),
        unreadNotifications: data.unreadNotifications,
        showAi: true,
        showProfile: true,
        capNotificationBadgeAt99: true,
        profileSemanticLabel: 'Teacher profile',
        onAiTap: () => _navigate('ai_copilot'),
        onNotificationsTap: () => _navigate('notifications'),
        onProfileTap: () => _navigate('profile'),
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : LayoutBuilder(
              builder: (context, constraints) {
                final isTablet =
                    constraints.maxWidth >= _tabletBreakpoint;
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
                          GreetingHeader(
                            eyebrow: data.greetingEyebrow,
                            headline: data.greetingHeadline,
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          AttendanceSummaryCard(
                            checkIn: data.checkIn,
                            summary: data.attendanceSummary,
                            onCheckInTap: () => _navigate('staff_check_in'),
                            onCheckInNowTap: () =>
                                _navigate('staff_check_in_now'),
                            onMarkAttendanceTap: () => _navigate(
                              'mark_attendance_${data.attendanceSummary.pendingClassId}',
                            ),
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          if (isTablet)
                            _TabletSplitBody(
                              data: data,
                              onNavigate: _navigate,
                            )
                          else
                            _MobileBody(
                              data: data,
                              onNavigate: _navigate,
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

  void _navigate(String actionId) {
    onNavigate?.call(actionId);
  }
}

class _MobileBody extends StatelessWidget {
  const _MobileBody({
    required this.data,
    required this.onNavigate,
  });

  final TeacherDashboardData data;
  final void Function(String actionId) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TodayScheduleCard(
          classes: data.todaySchedule,
          onTimetableTap: () => onNavigate('timetable'),
          onClassTap: (scheduleClass) =>
              onNavigate('class_${scheduleClass.id}'),
        ),
        const SizedBox(height: AksharaSpacing.s4),
        PendingTasksSection(
          tasks: data.pendingTasks,
          onTaskTap: (task) => onNavigate(task.id),
        ),
        const SizedBox(height: AksharaSpacing.s4),
        _QuickActionsSection(
          actions: data.quickActions,
          onNavigate: onNavigate,
        ),
        if (data.classTeacher != null) ...[
          const SizedBox(height: AksharaSpacing.s4),
          ClassTeacherCard(
            info: data.classTeacher!,
            onTap: () => onNavigate('class_teacher_dashboard'),
          ),
        ],
        const SizedBox(height: AksharaSpacing.s4),
        AksharaInsightCard(
          message: data.aiInsight.message,
          actionLabel: data.aiInsight.actionLabel,
          onAction: () => onNavigate('class_teacher_dashboard'),
        ),
      ],
    );
  }
}

class _TabletSplitBody extends StatelessWidget {
  const _TabletSplitBody({
    required this.data,
    required this.onNavigate,
  });

  final TeacherDashboardData data;
  final void Function(String actionId) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TodayScheduleCard(
                classes: data.todaySchedule,
                onTimetableTap: () => onNavigate('timetable'),
                onClassTap: (scheduleClass) =>
                    onNavigate('class_${scheduleClass.id}'),
              ),
            ),
            const SizedBox(width: AksharaSpacing.s4),
            Expanded(
              child: PendingTasksSection(
                tasks: data.pendingTasks,
                onTaskTap: (task) => onNavigate(task.id),
              ),
            ),
          ],
        ),
        const SizedBox(height: AksharaSpacing.s4),
        _QuickActionsSection(
          actions: data.quickActions,
          onNavigate: onNavigate,
        ),
        if (data.classTeacher != null) ...[
          const SizedBox(height: AksharaSpacing.s4),
          ClassTeacherCard(
            info: data.classTeacher!,
            onTap: () => onNavigate('class_teacher_dashboard'),
          ),
        ],
        const SizedBox(height: AksharaSpacing.s4),
        AksharaInsightCard(
          message: data.aiInsight.message,
          actionLabel: data.aiInsight.actionLabel,
          onAction: () => onNavigate('class_teacher_dashboard'),
        ),
      ],
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({
    required this.actions,
    required this.onNavigate,
  });

  final List<TeacherQuickAction> actions;
  final void Function(String actionId) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(
          title: 'Quick Actions',
          fixedHeight: false,
          spacingBelow: AksharaSpacing.s3,
        ),
        AksharaQuickActionGrid(
          children: [
            for (final action in actions)
              AksharaQuickActionCard(
                icon: action.icon,
                label: action.label,
                onTap: () => onNavigate(action.id),
              ),
          ],
        ),
      ],
    );
  }
}
