import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/communication/parent_communication_governance.dart';
import '../../../core/communication/teacher_student_risk_service.dart';
import '../../../core/repositories/mock/mock_student_risk_fixtures.dart';
import '../../../core/exams/exam_administration_store.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/semantic_status.dart';

/// Staff check-in state for the attendance summary area.
enum StaffCheckInStatus { checkedIn, notCheckedIn }

@immutable
class StaffCheckInInfo {
  const StaffCheckInInfo({
    required this.status,
    this.checkedInAt,
    this.verificationLabel,
  });

  final StaffCheckInStatus status;
  final String? checkedInAt;
  final String? verificationLabel;
}

@immutable
class AttendanceSummary {
  const AttendanceSummary({
    required this.pendingBannerMessage,
    required this.pendingBannerActionLabel,
    required this.pendingClassId,
    required this.classesMarked,
    required this.classesTotal,
    required this.studentsPresent,
    required this.studentsTotal,
  });

  final String? pendingBannerMessage;
  final String pendingBannerActionLabel;
  final String? pendingClassId;
  final int classesMarked;
  final int classesTotal;
  final int studentsPresent;
  final int studentsTotal;

  bool get hasPendingAttendance =>
      pendingBannerMessage != null && pendingBannerMessage!.isNotEmpty;
}

@immutable
class ScheduleClass {
  const ScheduleClass({
    required this.id,
    required this.timeLabel,
    required this.subject,
    required this.classLabel,
    required this.room,
    required this.status,
  });

  final String id;
  final String timeLabel;
  final String subject;
  final String classLabel;
  final String room;
  final ClassScheduleStatus status;
}

@immutable
class PendingTask {
  const PendingTask({
    required this.id,
    required this.icon,
    required this.count,
    required this.label,
    this.overdue = false,
  });

  final String id;
  final IconData icon;
  final int count;
  final String label;

  /// TCH-2 — the task is past its deadline (e.g. marks-entry overdue), so the
  /// tile is drawn with an urgent (error) tone.
  final bool overdue;
}

@immutable
class ClassTeacherInfo {
  const ClassTeacherInfo({
    required this.classLabel,
    required this.title,
  });

  final String classLabel;
  final String title;
}

@immutable
class TeacherQuickAction {
  const TeacherQuickAction({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

@immutable
class TeacherAiInsight {
  const TeacherAiInsight({
    required this.message,
    required this.actionLabel,
  });

  final String message;
  final String actionLabel;
}

/// Mock dashboard payload for [TeacherDashboardScreen] (TA-01).
@immutable
class TeacherDashboardData {
  const TeacherDashboardData({
    required this.teacherName,
    required this.greetingEyebrow,
    required this.greetingHeadline,
    required this.periodLabel,
    required this.unreadNotifications,
    required this.checkIn,
    required this.attendanceSummary,
    required this.todaySchedule,
    required this.pendingTasks,
    required this.classTeacher,
    required this.quickActions,
    required this.aiInsight,
    required this.studentsNeedingAttention,
  });

  final String teacherName;
  final String greetingEyebrow;
  final String greetingHeadline;
  final String periodLabel;
  final int unreadNotifications;
  final StaffCheckInInfo checkIn;
  final AttendanceSummary attendanceSummary;
  final List<ScheduleClass> todaySchedule;
  final List<PendingTask> pendingTasks;
  final ClassTeacherInfo? classTeacher;
  final List<TeacherQuickAction> quickActions;
  final TeacherAiInsight aiInsight;
  final List<StudentAttentionItem> studentsNeedingAttention;

  /// Honest-async contract neutral shape (WIDGET-002).
  ///
  /// Critically, `checkIn` is [StaffCheckInStatus.notCheckedIn] with no time and
  /// no verification label: the product never asserts a biometric check-in the
  /// teacher did not perform. No class, no roster counts, no timetable.
  factory TeacherDashboardData.empty() {
    return const TeacherDashboardData(
      teacherName: '',
      greetingEyebrow: '',
      greetingHeadline: '',
      periodLabel: '',
      unreadNotifications: 0,
      checkIn: StaffCheckInInfo(status: StaffCheckInStatus.notCheckedIn),
      attendanceSummary: AttendanceSummary(
        pendingBannerMessage: null,
        pendingBannerActionLabel: '',
        pendingClassId: null,
        classesMarked: 0,
        classesTotal: 0,
        studentsPresent: 0,
        studentsTotal: 0,
      ),
      todaySchedule: [],
      pendingTasks: [],
      classTeacher: null,
      quickActions: [],
      aiInsight: TeacherAiInsight(message: '', actionLabel: ''),
      studentsNeedingAttention: [],
    );
  }

  factory TeacherDashboardData.mock() {
    final context = TeacherTeachingContext.demoClassTeacher();
    final attention = MockStudentRiskFixtures.attentionForClass(context);
    // TCH-2 — marks still to enter, from the same marks-entry source that backs
    // /teacher/exams/marks (exams in the marks_entry phase with unfilled marks).
    final marksProgress = ExamAdministrationStore.instance.marksEntryProgress();
    final marksPending = marksProgress.fold<int>(
      0,
      (sum, p) => sum + (p.totalCount - p.enteredCount),
    );
    // TCH-2 — any exam past its marks-entry deadline with marks still pending
    // flags the home task as overdue (reuses the EXM-6 `isOverdue` signal).
    final marksOverdue =
        marksProgress.any((p) => p.isOverdue(DateTime.now()));
    return TeacherDashboardData(
      teacherName: 'Priya Sharma',
      greetingEyebrow: 'Friday, 5 Jun',
      greetingHeadline: 'Good morning, Priya',
      periodLabel: 'Period 3 · 10:30',
      // Live mode surfaces the backend's real count; the mock never fabricates 1.
      unreadNotifications: 0,
      checkIn: const StaffCheckInInfo(
        status: StaffCheckInStatus.checkedIn,
        checkedInAt: '9:02 AM',
        verificationLabel: 'Geo+Face verified',
      ),
      attendanceSummary: const AttendanceSummary(
        pendingBannerMessage: 'Attendance not marked for Class 8-A · Period 1',
        pendingBannerActionLabel: 'Mark now',
        pendingClassId: 'class-8a-p1',
        classesMarked: 1,
        classesTotal: 3,
        studentsPresent: 34,
        studentsTotal: 38,
      ),
      todaySchedule: [
        const ScheduleClass(
          id: 'sched-1',
          timeLabel: '09:00',
          subject: 'Mathematics',
          classLabel: '8-A',
          room: 'Room 204',
          status: ClassScheduleStatus.done,
        ),
        const ScheduleClass(
          id: 'sched-2',
          timeLabel: '11:00',
          subject: 'Mathematics',
          classLabel: '9-B',
          room: 'Room 206',
          status: ClassScheduleStatus.now,
        ),
        const ScheduleClass(
          id: 'sched-3',
          timeLabel: '14:00',
          subject: 'Mathematics',
          classLabel: '8-A',
          room: 'Room 204',
          status: ClassScheduleStatus.upcoming,
        ),
      ],
      pendingTasks: [
        const PendingTask(
          id: 'hw_review',
          icon: Icons.assignment_outlined,
          count: 5,
          label: 'HW to review',
        ),
        // TCH-2 — deep-links to the exams marks-entry surface when > 0; shows an
        // urgent "Marks overdue" tile once any exam is past its deadline.
        if (marksPending > 0)
          PendingTask(
            id: 'marks_pending',
            icon: Icons.grading_outlined,
            count: marksPending,
            label: marksOverdue ? 'Marks overdue' : 'Marks to enter',
            overdue: marksOverdue,
          ),
        const PendingTask(
          id: 'unread_messages',
          icon: Icons.chat_bubble_outline,
          count: 3,
          label: 'Unread messages',
        ),
        const PendingTask(
          id: 'leave',
          icon: Icons.event_busy_outlined,
          count: 1,
          label: 'Leave request',
        ),
      ],
      classTeacher: const ClassTeacherInfo(
        classLabel: '8-A',
        title: 'Class Teacher · 8-A Dashboard',
      ),
      quickActions: [
        const TeacherQuickAction(
          id: 'mark_attendance',
          label: 'Attendance',
          icon: Icons.fact_check_outlined,
        ),
        // TCH-5 — quick action to create homework straight from home.
        const TeacherQuickAction(
          id: 'create_homework',
          label: 'Create HW',
          icon: Icons.post_add_outlined,
        ),
        const TeacherQuickAction(
          id: 'homework',
          label: 'Homework',
          icon: Icons.assignment_outlined,
        ),
        // TCH-9 — the teacher's own attendance history (read-only).
        const TeacherQuickAction(
          id: 'my_attendance',
          label: 'My attendance',
          icon: Icons.badge_outlined,
        ),
        const TeacherQuickAction(
          id: 'timetable',
          label: 'Timetable',
          icon: Icons.calendar_view_week_outlined,
        ),
        const TeacherQuickAction(
          id: 'exams',
          label: 'Exams',
          icon: Icons.grading_outlined,
        ),
        const TeacherQuickAction(
          id: 'messages',
          label: 'Messages',
          icon: Icons.forum_outlined,
        ),
      ],
      aiInsight: TeacherAiInsight(
        message: attention.isEmpty
            ? 'No urgent student alerts today.'
            : '${attention.length} students in 8-A require attention today.',
        actionLabel: 'Open class dashboard',
      ),
      studentsNeedingAttention: attention,
    );
  }
}

final teacherDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final teacherDashboardErrorProvider = StateProvider<bool>((ref) => false);
final teacherDashboardEmptyProvider = StateProvider<bool>((ref) => false);

final teacherDashboardFutureProvider = FutureProvider<TeacherDashboardData>((ref) async {
  return ref.read(teacherRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

/// WIDGET-002 — honest-async contract for `/teacher/dashboard`. The dashboard
/// can no longer report a "9:02 AM · Geo+Face verified" check-in that never
/// happened, on either the loading or the failure path.
final teacherDashboardViewStateProvider =
    Provider<ErpViewState<TeacherDashboardData>>((ref) {
  return resolveErpAsync<TeacherDashboardData>(
    ref.watch(teacherDashboardFutureProvider),
    forceLoading: ref.watch(teacherDashboardLoadingProvider),
    forceError: ref.watch(teacherDashboardErrorProvider),
    forceEmpty: ref.watch(teacherDashboardEmptyProvider),
    errorMessage: 'Unable to load your dashboard.',
  );
});

final teacherDashboardProvider = Provider<TeacherDashboardData>((ref) {
  return honestPayload(
    ref.watch(teacherDashboardViewStateProvider),
    TeacherDashboardData.empty,
  );
});
