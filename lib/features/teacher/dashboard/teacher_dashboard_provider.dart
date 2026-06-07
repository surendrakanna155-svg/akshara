import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
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
  });

  final String id;
  final IconData icon;
  final int count;
  final String label;
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

  factory TeacherDashboardData.mock() {
    return const TeacherDashboardData(
      teacherName: 'Priya Sharma',
      greetingEyebrow: 'Friday, 5 Jun',
      greetingHeadline: 'Good morning, Priya',
      periodLabel: 'Period 3 · 10:30',
      unreadNotifications: 1,
      checkIn: StaffCheckInInfo(
        status: StaffCheckInStatus.checkedIn,
        checkedInAt: '9:02 AM',
        verificationLabel: 'Geo+Face verified',
      ),
      attendanceSummary: AttendanceSummary(
        pendingBannerMessage: 'Attendance not marked for Class 8-A · Period 1',
        pendingBannerActionLabel: 'Mark now',
        pendingClassId: 'class-8a-p1',
        classesMarked: 1,
        classesTotal: 3,
        studentsPresent: 34,
        studentsTotal: 38,
      ),
      todaySchedule: [
        ScheduleClass(
          id: 'sched-1',
          timeLabel: '09:00',
          subject: 'Mathematics',
          classLabel: '8-A',
          room: 'Room 204',
          status: ClassScheduleStatus.done,
        ),
        ScheduleClass(
          id: 'sched-2',
          timeLabel: '11:00',
          subject: 'Mathematics',
          classLabel: '9-B',
          room: 'Room 206',
          status: ClassScheduleStatus.now,
        ),
        ScheduleClass(
          id: 'sched-3',
          timeLabel: '14:00',
          subject: 'Mathematics',
          classLabel: '8-A',
          room: 'Room 204',
          status: ClassScheduleStatus.upcoming,
        ),
      ],
      pendingTasks: [
        PendingTask(
          id: 'hw_review',
          icon: Icons.assignment_outlined,
          count: 5,
          label: 'HW to review',
        ),
        PendingTask(
          id: 'unread_messages',
          icon: Icons.chat_bubble_outline,
          count: 3,
          label: 'Unread messages',
        ),
        PendingTask(
          id: 'leave',
          icon: Icons.event_busy_outlined,
          count: 1,
          label: 'Leave request',
        ),
      ],
      classTeacher: ClassTeacherInfo(
        classLabel: '8-A',
        title: 'Class Teacher · 8-A Dashboard',
      ),
      quickActions: [
        TeacherQuickAction(
          id: 'mark_attendance',
          label: 'Attendance',
          icon: Icons.fact_check_outlined,
        ),
        TeacherQuickAction(
          id: 'homework',
          label: 'Homework',
          icon: Icons.assignment_outlined,
        ),
        TeacherQuickAction(
          id: 'timetable',
          label: 'Timetable',
          icon: Icons.calendar_view_week_outlined,
        ),
        TeacherQuickAction(
          id: 'exams',
          label: 'Exams',
          icon: Icons.grading_outlined,
        ),
        TeacherQuickAction(
          id: 'messages',
          label: 'Messages',
          icon: Icons.forum_outlined,
        ),
      ],
      aiInsight: TeacherAiInsight(
        message: '3 students in 8-A were absent twice this week — follow up?',
        actionLabel: 'View class',
      ),
    );
  }
}

final teacherDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final teacherDashboardErrorProvider = StateProvider<bool>((ref) => false);
final teacherDashboardEmptyProvider = StateProvider<bool>((ref) => false);

final teacherDashboardFutureProvider = FutureProvider<TeacherDashboardData>((ref) async {
  return ref.read(teacherRepositoryProvider).getDashboard(query: ref.watch(repositoryQueryProvider));
});

final teacherDashboardProvider = Provider<TeacherDashboardData>((ref) {
  final data = watchRepositoryFuture(
    ref,
    ref.watch(teacherDashboardFutureProvider),
    manualLoading: ref.watch(teacherDashboardLoadingProvider),
    manualError: ref.watch(teacherDashboardErrorProvider),
    manualEmpty: ref.watch(teacherDashboardEmptyProvider),
  );
  return data ??
      ref.watch(teacherDashboardFutureProvider).value ??
      TeacherDashboardData.mock();
});
