import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../shared/semantic_status.dart';

/// Homework submission status for due list rows.
enum HomeworkStatus { pending, overdue }

@immutable
class SchedulePeriod {
  const SchedulePeriod({
    required this.id,
    required this.timeLabel,
    required this.subject,
    required this.teacherName,
    required this.state,
  });

  final String id;
  final String timeLabel;
  final String subject;
  final String teacherName;
  final PeriodState state;
}

@immutable
class AttendanceKpi {
  const AttendanceKpi({
    required this.label,
    required this.value,
    required this.detail,
    required this.tone,
  });

  final String label;
  final String value;
  final String detail;
  final StudentKpiTone tone;
}

@immutable
class HomeworkDueItem {
  const HomeworkDueItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueLabel,
    required this.status,
    required this.icon,
  });

  final String id;
  final String title;
  final String subject;
  final String dueLabel;
  final HomeworkStatus status;
  final IconData icon;
}

@immutable
class ExamReminder {
  const ExamReminder({
    required this.id,
    required this.title,
    required this.subject,
    required this.dateLabel,
    required this.daysUntil,
  });

  final String id;
  final String title;
  final String subject;
  final String dateLabel;
  final int daysUntil;
}

@immutable
class StudentQuickAction {
  const StudentQuickAction({
    required this.id,
    required this.label,
    required this.icon,
    this.emphasis = StudentKpiTone.primary,
    this.isVisible = true,
  });

  final String id;
  final String label;
  final IconData icon;
  final StudentKpiTone emphasis;
  final bool isVisible;
}

@immutable
class StudentAiInsight {
  const StudentAiInsight({
    required this.message,
    required this.actionLabel,
  });

  final String message;
  final String actionLabel;
}

/// Mock dashboard payload for [StudentDashboardScreen] (ST-01).
@immutable
class StudentDashboardData {
  const StudentDashboardData({
    required this.studentName,
    required this.classLabel,
    required this.greetingHeadline,
    required this.greetingSubtitle,
    required this.unreadNotifications,
    required this.todaySchedule,
    required this.attendanceKpi,
    required this.homeworkDue,
    required this.examReminder,
    required this.quickActions,
    required this.aiInsight,
  });

  final String studentName;
  final String classLabel;
  final String greetingHeadline;
  final String greetingSubtitle;
  final int unreadNotifications;
  final List<SchedulePeriod> todaySchedule;
  final AttendanceKpi attendanceKpi;
  final List<HomeworkDueItem> homeworkDue;
  final ExamReminder examReminder;
  final List<StudentQuickAction> quickActions;
  final StudentAiInsight aiInsight;

  factory StudentDashboardData.mock() {
    return const StudentDashboardData(
      studentName: 'Ravi Kumar',
      classLabel: '8-A',
      greetingHeadline: 'Hey Ravi! 👋',
      greetingSubtitle: 'Ready for Period 3?',
      unreadNotifications: 2,
      todaySchedule: [
        SchedulePeriod(
          id: 'period-1',
          timeLabel: '10:30',
          subject: 'Science',
          teacherName: 'Mrs. Rao',
          state: PeriodState.now,
        ),
        SchedulePeriod(
          id: 'period-2',
          timeLabel: '11:30',
          subject: 'English',
          teacherName: 'Mr. Patel',
          state: PeriodState.next,
        ),
        SchedulePeriod(
          id: 'period-3',
          timeLabel: '14:00',
          subject: 'PE',
          teacherName: 'Coach Singh',
          state: PeriodState.later,
        ),
        SchedulePeriod(
          id: 'period-4',
          timeLabel: '15:00',
          subject: 'Mathematics',
          teacherName: 'Mrs. Sharma',
          state: PeriodState.later,
        ),
      ],
      attendanceKpi: AttendanceKpi(
        label: 'Present today',
        value: 'Present',
        detail: 'Marked 9:12 AM · All sessions',
        tone: StudentKpiTone.success,
      ),
      homeworkDue: [
        HomeworkDueItem(
          id: 'hw-1',
          title: 'Algebra worksheet',
          subject: 'Math',
          dueLabel: 'Due tomorrow',
          status: HomeworkStatus.pending,
          icon: Icons.calculate_outlined,
        ),
        HomeworkDueItem(
          id: 'hw-2',
          title: 'Photosynthesis lab report',
          subject: 'Science',
          dueLabel: 'Due today · Overdue',
          status: HomeworkStatus.overdue,
          icon: Icons.biotech_outlined,
        ),
      ],
      examReminder: ExamReminder(
        id: 'exam-1',
        title: 'Mid-term Mathematics',
        subject: 'Math · Unit 4–6',
        dateLabel: '12 Jun 2026 · 9:00 AM',
        daysUntil: 7,
      ),
      quickActions: [
        // STU-7: no "Join Class" — there is no live-class/video feature; the
        // action only routed to the timetable, implying a capability we lack.
        StudentQuickAction(
          id: 'submit_homework',
          label: 'Submit HW',
          icon: Icons.assignment_outlined,
          emphasis: StudentKpiTone.warning,
        ),
        StudentQuickAction(
          id: 'report_card',
          label: 'Report Card',
          icon: Icons.description_outlined,
          emphasis: StudentKpiTone.primary,
        ),
        StudentQuickAction(
          id: 'progress',
          label: 'Progress',
          icon: Icons.trending_up_outlined,
          emphasis: StudentKpiTone.primary,
        ),
      ],
      // STU-6: honest CTA to the real AI tutor (the action opens live AI) rather
      // than a fabricated, static "AI insight" about the student.
      aiInsight: StudentAiInsight(
        message: 'Ask your AI study buddy for help with today’s lessons',
        actionLabel: 'Open AI tutor',
      ),
    );
  }
}

final studentDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final studentDashboardErrorProvider = StateProvider<bool>((ref) => false);
final studentDashboardEmptyProvider = StateProvider<bool>((ref) => false);

final studentDashboardFutureProvider = FutureProvider<StudentDashboardData>((ref) async {
  return ref.read(studentRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

final studentDashboardProvider = Provider<StudentDashboardData>((ref) {
  final data = watchRepositoryFuture(
    ref,
    ref.watch(studentDashboardFutureProvider),
    manualLoading: ref.watch(studentDashboardLoadingProvider),
    manualError: ref.watch(studentDashboardErrorProvider),
    manualEmpty: ref.watch(studentDashboardEmptyProvider),
  );
  return data ??
      ref.watch(studentDashboardFutureProvider).value ??
      StudentDashboardData.mock();
});
