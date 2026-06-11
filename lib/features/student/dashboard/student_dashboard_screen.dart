import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'student_dashboard_provider.dart';
import 'widgets/attendance_kpi_card.dart';
import 'widgets/daily_schedule_strip.dart';
import 'widgets/exam_reminder_card.dart';
import 'widgets/hero_greeting_card.dart';
import 'widgets/homework_due_list.dart';

/// Student home dashboard — ST-01 `ST-01-StudentDashboard-M`.
class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({
    super.key,
    this.onNavigate,
  });

  /// Route handler; receives action ids from ST-01 prototype map.
  final void Function(String actionId)? onNavigate;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;
  static const double _largeMobileBreakpoint = 428;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(studentDashboardProvider);
    final isLoading = ref.watch(studentDashboardLoadingProvider);
    final hasError = ref.watch(studentDashboardErrorProvider);
    final overdueCount =
        data.homeworkDue.where((h) => h.status == HomeworkStatus.overdue).length;
    final dueCount = data.homeworkDue.length;

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Home',
        titleTrailing: AksharaContextChip(
          label: data.classLabel,
          semanticLabel: 'Class ${data.classLabel}',
          fontWeight: FontWeight.w600,
        ),
        unreadNotifications: data.unreadNotifications,
        showAi: true,
        showProfile: true,
        capNotificationBadgeAt99: true,
        aiTooltip: 'AI Study Assistant',
        profileSemanticLabel: 'Student profile',
        onAiTap: () => _navigate(onNavigate, 'ai_assistant'),
        onNotificationsTap: () => _navigate(onNavigate, 'notifications'),
        onProfileTap: () => _navigate(onNavigate, 'profile'),
      ),
      body: isLoading
          ? const AksharaLoadingState()
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load your dashboard.',
                  onRetry: () =>
                      ref.read(studentDashboardErrorProvider.notifier).state = false,
                )
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
                          HeroGreetingCard(
                            headline: data.greetingHeadline,
                            subtitle: data.greetingSubtitle,
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          DailyScheduleStrip(
                            periods: data.todaySchedule,
                            largeMobileBreakpoint: _largeMobileBreakpoint,
                            onFullScheduleTap: () =>
                                _navigate(onNavigate, 'full_schedule'),
                            onPeriodTap: (period) =>
                                _navigate(onNavigate, 'period_${period.id}'),
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          AksharaQuickActionRow(
                            largeMobileBreakpoint: _largeMobileBreakpoint,
                            children: [
                              for (final action
                                  in data.quickActions.where((a) => a.isVisible))
                                AksharaQuickActionCard(
                                  icon: action.icon,
                                  label: action.label,
                                  emphasis: action.emphasis,
                                  labelFontWeight: FontWeight.w600,
                                  horizontalPadding: AksharaSpacing.s3,
                                  verticalPadding: AksharaSpacing.s4,
                                  onTap: () =>
                                      _navigate(onNavigate, action.id),
                                ),
                            ],
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          _StatusKpiRow(
                            attendanceKpi: data.attendanceKpi,
                            homeworkCount: dueCount,
                            homeworkLabel: overdueCount > 0
                                ? 'HW due · $overdueCount overdue'
                                : 'HW due',
                            largeMobileBreakpoint: _largeMobileBreakpoint,
                            onAttendanceTap: () =>
                                _navigate(onNavigate, 'attendance'),
                            onHomeworkKpiTap: () =>
                                _navigate(onNavigate, 'homework_list'),
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          ExamReminderCard(
                            reminder: data.examReminder,
                            onTap: () => _navigate(
                              onNavigate,
                              'exam_${data.examReminder.id}',
                            ),
                          ),
                          const SizedBox(height: AksharaSpacing.s4),
                          if (isTablet)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: HomeworkDueList(
                                    items: data.homeworkDue,
                                    onSeeAllTap: () => _navigate(
                                      onNavigate,
                                      'homework_list',
                                    ),
                                    onItemTap: (item) => _navigate(
                                      onNavigate,
                                      'homework_${item.id}',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AksharaSpacing.s4),
                                Expanded(
                                  child: AksharaInsightCard(
                                    message: data.aiInsight.message,
                                    actionLabel: data.aiInsight.actionLabel,
                                    icon: Icons.auto_stories_outlined,
                                    semanticLabelPrefix: 'AI study insight',
                                    onAction: () => _navigate(
                                      onNavigate,
                                      'ai_quiz',
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            HomeworkDueList(
                              items: data.homeworkDue,
                              onSeeAllTap: () =>
                                  _navigate(onNavigate, 'homework_list'),
                              onItemTap: (item) =>
                                  _navigate(onNavigate, 'homework_${item.id}'),
                            ),
                            const SizedBox(height: AksharaSpacing.s4),
                            AksharaInsightCard(
                              message: data.aiInsight.message,
                              actionLabel: data.aiInsight.actionLabel,
                              icon: Icons.auto_stories_outlined,
                              semanticLabelPrefix: 'AI study insight',
                              onAction: () =>
                                  _navigate(onNavigate, 'ai_quiz'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _navigate(void Function(String actionId)? handler, String actionId) {
    handler?.call(actionId);
  }
}

class _StatusKpiRow extends StatelessWidget {
  const _StatusKpiRow({
    required this.attendanceKpi,
    required this.homeworkCount,
    required this.homeworkLabel,
    required this.onAttendanceTap,
    required this.onHomeworkKpiTap,
    this.largeMobileBreakpoint = 428,
  });

  final AttendanceKpi attendanceKpi;
  final int homeworkCount;
  final String homeworkLabel;
  final VoidCallback? onAttendanceTap;
  final VoidCallback? onHomeworkKpiTap;
  final double largeMobileBreakpoint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Status summary',
      child: Row(
        children: [
          Expanded(
            child: AttendanceKpiCard(
              kpi: attendanceKpi,
              largeMobileBreakpoint: largeMobileBreakpoint,
              onTap: onAttendanceTap,
            ),
          ),
          const SizedBox(width: AksharaSpacing.s3),
          Expanded(
            child: HomeworkCountKpiCard(
              count: homeworkCount,
              label: homeworkLabel,
              onTap: onHomeworkKpiTap,
            ),
          ),
        ],
      ),
    );
  }
}
