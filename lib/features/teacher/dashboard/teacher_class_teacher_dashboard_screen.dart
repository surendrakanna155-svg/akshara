import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import '../../../router/student360_navigation.dart';
import '../../../shared/layout/mobile_dashboard_layout.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../communication/teacher_teaching_context_provider.dart';
import '../dashboard/teacher_dashboard_provider.dart';
import '../leave_approvals/teacher_leave_approvals_screen.dart';
import '../timetable/teacher_today_screen.dart';

/// TA-01 class teacher dashboard (dedicated overview).
class TeacherClassTeacherDashboardScreen extends ConsumerWidget {
  const TeacherClassTeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(teacherDashboardProvider);
    final isLoading = ref.watch(teacherDashboardLoadingProvider);
    final hasError = ref.watch(teacherDashboardErrorProvider);
    final isEmpty = ref.watch(teacherDashboardEmptyProvider);

    final classTeacher = data.classTeacher;
    final attention = data.studentsNeedingAttention;
    final pendingConcerns =
        ref.watch(pendingSubjectConcernsProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AksharaAppBar(
        titleText: 'Class Teacher',
        titleTrailing: AksharaContextChip(
          label: classTeacher?.classLabel ?? '—',
          semanticLabel:
              'Class teacher for ${classTeacher?.classLabel ?? "Unknown"}',
        ),
        unreadNotifications: data.unreadNotifications,
        showAi: true,
        showProfile: true,
        // P1-5 (2026-07-28) — MUST be push, not go. `/ai-assistant` is a
        // top-level route outside every shell, so `go` collapses the stack;
        // CopilotPersonaShellScreen's back arrow then calls `context.pop()`
        // with nothing to pop (it throws), and the screen has no bottom nav —
        // force-quit was the only exit. Every other caller uses push.
        onAiTap: () => context.push(RouteNames.aiAssistant),
        // F-128 — teacher-scoped notifications inbox (not the parent route).
        onNotificationsTap: () => context.push(RouteNames.teacherNotifications),
        // F-164 — the profile avatar opens the teacher profile, not Home.
        onProfileTap: () => context.go(RouteNames.teacherProfile),
      ),
      body: MobileAsyncBody(
        isLoading: isLoading,
        hasError: hasError,
        isEmpty: isEmpty,
        onRetry: () => ref.invalidate(teacherDashboardFutureProvider),
        builder: (context) {
          // DS V2 P4 — premium persona canvas behind the class-teacher overview
          // (a navigation/quick-actions dashboard, no headline % → no ring).
          if (classTeacher == null) {
            return const AksharaPremiumBackground(
              motif: AksharaMotif.book,
              child: AksharaEmptyState(
                message: 'Class teacher dashboard is not available.',
                icon: Icons.groups_outlined,
              ),
            );
          }

          return AksharaPremiumBackground(
            motif: AksharaMotif.book,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.of(context).size.width;
                return SingleChildScrollView(
                  child: Padding(
                    padding: MobileDashboardLayout.screenPadding(width),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AksharaSectionHeader(
                          title: classTeacher.title,
                          fixedHeight: false,
                          spacingBelow: AksharaSpacing.s2,
                        ),
                        const SizedBox(height: AksharaSpacing.s3),
                        AksharaInsightCard(
                          message:
                              'Quick actions for ${classTeacher.classLabel}. Attendance, homework review, exams, and class comms.',
                          actionLabel: 'Go to attendance',
                          onAction: () =>
                              context.go(RouteNames.teacherAttendance),
                        ),
                        const SizedBox(height: AksharaSpacing.s4),
                        if (pendingConcerns.isNotEmpty)
                          AksharaWarningBanner(
                            message:
                                '${pendingConcerns.length} subject teacher concern(s) awaiting your review.',
                            actionLabel: 'Review',
                            onAction: () => context
                                .go(RouteNames.teacherParentCommunication),
                            compactMessage: true,
                          ),
                        if (pendingConcerns.isNotEmpty)
                          const SizedBox(height: AksharaSpacing.s3),
                        if (attention.isNotEmpty) ...[
                          const AksharaSectionHeader(
                            title: 'Students requiring attention',
                            fixedHeight: false,
                          ),
                          const SizedBox(height: AksharaSpacing.s2),
                          for (final item in attention)
                            ListTile(
                              title: Text(item.studentName),
                              subtitle: Text(item.summary),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  openStudent360(context, item.sisStudentId),
                              onLongPress: () => context.push(
                                RouteNames.teacherStudentRisk(
                                    item.sisStudentId),
                              ),
                            ),
                          const SizedBox(height: AksharaSpacing.s4),
                        ],
                        AksharaQuickActionGrid(
                          children: [
                            AksharaQuickActionCard(
                              icon: Icons.fact_check_outlined,
                              label: 'Attendance',
                              onTap: () =>
                                  context.go(RouteNames.teacherAttendance),
                            ),
                            AksharaQuickActionCard(
                              icon: Icons.assignment_outlined,
                              label: 'Homework',
                              onTap: () =>
                                  context.go(RouteNames.teacherHomework),
                            ),
                            AksharaQuickActionCard(
                              icon: Icons.calendar_view_week_outlined,
                              label: 'Timetable',
                              onTap: () =>
                                  context.go(RouteNames.teacherTimetable),
                            ),
                            AksharaQuickActionCard(
                              icon: Icons.grading_outlined,
                              label: 'Exams',
                              onTap: () => context.go(RouteNames.teacherExams),
                            ),
                            AksharaQuickActionCard(
                              icon: Icons.campaign_outlined,
                              label: 'Parent comms',
                              onTap: () => context
                                  .go(RouteNames.teacherParentCommunication),
                            ),
                            AksharaQuickActionCard(
                              icon: Icons.event_available_outlined,
                              label: 'Leave requests',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const TeacherLeaveApprovalsScreen(),
                                ),
                              ),
                            ),
                            AksharaQuickActionCard(
                              icon: Icons.today_outlined,
                              label: "Today's classes",
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const TeacherTodayScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
