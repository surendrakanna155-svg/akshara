import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/liveness/live_refresh_scope.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../shared/layout/mobile_dashboard_layout.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../adaptive_ai/adaptive_ai_models.dart';
import '../../adaptive_ai/widgets/adaptive_priority_feed.dart';
import 'teacher_dashboard_provider.dart';
import 'widgets/attendance_summary_card.dart';
import 'widgets/class_teacher_card.dart';
import 'widgets/cover_alert_card.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WIDGET-002 — honest-async contract.
    final state = ref.watch(teacherDashboardViewStateProvider);
    final data = ref.watch(teacherDashboardProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: 'Dashboard',
        titleTrailing: state.hasData && data.periodLabel.isNotEmpty
            ? AksharaContextChip(
                label: data.periodLabel,
                semanticLabel: 'Current period: ${data.periodLabel}',
              )
            : null,
        unreadNotifications: state.hasData ? data.unreadNotifications : 0,
        showAi: true,
        showProfile: true,
        capNotificationBadgeAt99: true,
        profileSemanticLabel: 'Teacher profile',
        onAiTap: () => _navigate('ai_copilot'),
        onNotificationsTap: () => _navigate('notifications'),
        onProfileTap: () => _navigate('profile'),
      ),
      // Living Dashboard §3.5 — refresh on resume and on a slow
      // foreground tick; never while offline or backgrounded.
      body: LiveRefreshScope(
        surfaceKey: 'teacher-dashboard',
        onRefresh: () => ref.invalidate(teacherDashboardFutureProvider),
        child: MobileAsyncBody.fromState(
        state,
        loadingLabel: 'Loading dashboard',
        emptyMessage:
            'Your teaching day will appear here once the school publishes '
            "today's timetable and rosters.",
        onRetry: () {
          ref.read(teacherDashboardErrorProvider.notifier).state = false;
          ref.invalidate(teacherDashboardFutureProvider);
        },
        skeleton: AksharaSkeleton.dashboard(),
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isTablet = MobileDashboardLayout.isTablet(width);

            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(teacherDashboardFutureProvider),
              child: AksharaPremiumBackground(
                motif: AksharaMotif.book,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: MobileDashboardLayout.screenPadding(width),
                  child: ConstrainedBox(
                    constraints:
                        MobileDashboardLayout.contentConstraints(width),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AksharaGradientHero(
                          eyebrow: data.greetingEyebrow,
                          headline: data.greetingHeadline,
                          motif: AksharaMotif.book,
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
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  void _navigate(String actionId) {
    onNavigate?.call(actionId);
  }
}

/// Map an Adaptive AI recommendation's (logical) deep link to the teacher route.
/// The human lands on the module and acts there — the AI only navigated.
void _openTeacherAdaptiveAction(BuildContext context, AdaptiveAction action) {
  final link = action.deepLink;
  final route = link.startsWith('/teacher/attendance')
      ? RouteNames.teacherAttendance
      : link.startsWith('/teacher/homework')
          ? RouteNames.teacherHomework
          : link.startsWith('/teacher/exams')
              ? RouteNames.teacherExams
              : RouteNames.teacherDashboard;
  context.go(route);
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
        // TCH-4 — cover-duty alert (self-hiding when there is no cover today).
        CoverAlertCard(onOpenTimetable: () => onNavigate('timetable')),
        TodayScheduleCard(
          classes: data.todaySchedule,
          onTimetableTap: () => onNavigate('timetable'),
          // TCH-1 — tapping a today-schedule row jumps straight to marking
          // attendance for that class (not the weekly timetable).
          onClassTap: (scheduleClass) =>
              onNavigate('schedule_attendance_${scheduleClass.classLabel}'),
        ),
        const SizedBox(height: AksharaSpacing.s4),
        _StudentsNeedingAttentionSection(
          data: data,
          onNavigate: onNavigate,
        ),
        const SizedBox(height: AksharaSpacing.s4),
        // W2 Adaptive AI feed — real per-class items (attendance/homework/exam),
        // self-hides when empty. onOpenAction navigates to the module; the human
        // acts there (AI never executes).
        const AdaptivePriorityFeedSection(
          persona: 'teacher',
          onOpenAction: _openTeacherAdaptiveAction,
        ),
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
        AksharaAiSuggestionBar(
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
        // TCH-4 — cover-duty alert (self-hiding when there is no cover today).
        CoverAlertCard(onOpenTimetable: () => onNavigate('timetable')),
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
        _StudentsNeedingAttentionSection(
          data: data,
          onNavigate: onNavigate,
        ),
        const SizedBox(height: AksharaSpacing.s4),
        // The priority feed was present on the mobile body but missing here, so
        // a teacher on a tablet silently lost their "what to do next" list — the
        // one surface that is supposed to be persona-wide. Self-hides when empty.
        const AdaptivePriorityFeedSection(
          persona: 'teacher',
          onOpenAction: _openTeacherAdaptiveAction,
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
        AksharaAiSuggestionBar(
          message: data.aiInsight.message,
          actionLabel: data.aiInsight.actionLabel,
          onAction: () => onNavigate('class_teacher_dashboard'),
        ),
      ],
    );
  }
}

class _StudentsNeedingAttentionSection extends StatelessWidget {
  const _StudentsNeedingAttentionSection({
    required this.data,
    required this.onNavigate,
  });

  final TeacherDashboardData data;
  final void Function(String actionId) onNavigate;

  @override
  Widget build(BuildContext context) {
    final items = data.studentsNeedingAttention;
    if (items.isEmpty && !data.attendanceSummary.hasPendingAttendance) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(
          title: 'Students requiring attention today',
          fixedHeight: false,
          spacingBelow: AksharaSpacing.s3,
        ),
        if (data.attendanceSummary.hasPendingAttendance)
          Padding(
            padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
            child: AksharaWarningBanner(
              message: data.attendanceSummary.pendingBannerMessage!,
              actionLabel: data.attendanceSummary.pendingBannerActionLabel,
              onAction: () => onNavigate('mark_attendance'),
              compactMessage: true,
            ),
          ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AksharaSpacing.s2),
            child: AksharaWarningBanner(
              message: '${item.studentName}: ${item.summary}',
              actionLabel: 'Review',
              onAction: () => onNavigate('student_risk_${item.sisStudentId}'),
              compactMessage: true,
            ),
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
