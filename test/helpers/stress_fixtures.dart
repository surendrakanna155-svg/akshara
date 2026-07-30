import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_provider.dart';
import 'package:akshara_erp/features/student_app/dashboard/student_dashboard_provider.dart';
import 'package:akshara_erp/features/teacher/dashboard/teacher_dashboard_provider.dart';
import 'package:akshara_erp/shared/semantic_status.dart';
import 'package:flutter/material.dart';

/// Long-string stress data for UI layout validation.
abstract final class StressFixtures {
  static const longSchoolName =
      'NIKSHA International Residential Public School and Junior College Campus North Block';
  static const longPersonName =
      'Venkataramana Subrahmanyam Chidambaram Iyer Kumaraswamy';
  static const longSubjectName =
      'Advanced Mathematics Olympiad Preparation and Problem Solving Workshop';
  static const longInventoryItem =
      'Heavy-duty adjustable laboratory stool with anti-slip rubber base grade-A';
  static const longStatusLabel =
      'Attendance marked present with late entry note from class teacher';

  static const stressViewports = <({String label, Size size})>[
    (label: '360x640', size: Size(360, 640)),
    (label: '375x812', size: Size(375, 812)),
    (label: '390x844', size: Size(390, 844)),
    (label: '412x915', size: Size(412, 915)),
    (label: '428x926', size: Size(428, 926)),
    (label: '768x1024', size: Size(768, 1024)),
    (label: '834x1194', size: Size(834, 1194)),
    (label: '1024x1366', size: Size(1024, 1366)),
  ];

  static const textScales = [0.8, 1.0, 1.25, 1.5, 2.0];

  static ParentDashboardData stressParentDashboard() {
    final base = ParentDashboardData.mock();
    return ParentDashboardData(
      childName: longPersonName,
      childClass: 'Grade 12-A International Science Stream',
      greetingEyebrow: 'Good morning from $longSchoolName',
      greetingHeadline:
          "$longPersonName's comprehensive daily academic and co-curricular overview",
      schoolName: longSchoolName,
      statusChips: [
        const DashboardStatusChip(label: longStatusLabel, tone: DashboardChipTone.success),
        const DashboardStatusChip(
          label: '₹1,24,500 term fee installment overdue immediately',
          tone: DashboardChipTone.warning,
        ),
        const DashboardStatusChip(
          label: '14 unread messages from teachers and administration',
          tone: DashboardChipTone.primary,
        ),
      ],
      quickActions: base.quickActions,
      todaySummary: base.todaySummary,
      notices: [
        const DashboardNotice(
          id: 'stress-n1',
          title:
              'Mandatory parent-teacher meeting for $longSubjectName elective batch confirmation',
          dateLabel: 'Today',
          isUrgent: true,
        ),
      ],
      events: base.events,
      aiInsight: base.aiInsight,
      unreadNotifications: base.unreadNotifications,
    );
  }

  static TeacherDashboardData stressTeacherDashboard() {
    final base = TeacherDashboardData.mock();
    return TeacherDashboardData(
      teacherName: longPersonName,
      greetingEyebrow: 'Wednesday at $longSchoolName',
      greetingHeadline: 'Good morning, $longPersonName',
      periodLabel: 'Period 4 · $longSubjectName',
      unreadNotifications: base.unreadNotifications,
      checkIn: base.checkIn,
      attendanceSummary: base.attendanceSummary,
      todaySchedule: [
        const ScheduleClass(
          id: 'stress-1',
          timeLabel: '09:00',
          subject: longSubjectName,
          classLabel: 'Grade 12-A International Science Stream',
          room: 'Laboratory Block C Room 204 Extended Wing',
          status: ClassScheduleStatus.now,
        ),
      ],
      pendingTasks: base.pendingTasks,
      classTeacher: base.classTeacher,
      quickActions: base.quickActions,
      aiInsight: base.aiInsight,
      studentsNeedingAttention: base.studentsNeedingAttention,
    );
  }

  static StudentDashboardData stressStudentDashboard() {
    final base = StudentDashboardData.mock();
    return StudentDashboardData(
      studentName: longPersonName,
      greetingHeadline: longPersonName,
      greetingSubtitle: longSubjectName,
      classLabel: 'Grade 12-A International Science Stream',
      unreadNotifications: base.unreadNotifications,
      todaySchedule: base.todaySchedule,
      quickActions: base.quickActions,
      attendanceKpi: base.attendanceKpi,
      homeworkDue: base.homeworkDue,
      examReminder: base.examReminder,
      aiInsight: base.aiInsight,
    );
  }

  static ParentDashboardData emptyParentDashboard() {
    final base = ParentDashboardData.mock();
    return ParentDashboardData(
      childName: base.childName,
      childClass: base.childClass,
      greetingEyebrow: base.greetingEyebrow,
      greetingHeadline: base.greetingHeadline,
      schoolName: base.schoolName,
      statusChips: const [],
      quickActions: base.quickActions,
      todaySummary: const [],
      notices: const [],
      events: const [],
      aiInsight: base.aiInsight,
      unreadNotifications: 0,
    );
  }

  static TeacherDashboardData emptyTeacherDashboard() {
    final base = TeacherDashboardData.mock();
    return TeacherDashboardData(
      teacherName: base.teacherName,
      greetingEyebrow: base.greetingEyebrow,
      greetingHeadline: base.greetingHeadline,
      periodLabel: base.periodLabel,
      unreadNotifications: 0,
      checkIn: base.checkIn,
      attendanceSummary: const AttendanceSummary(
        pendingBannerMessage: null,
        pendingBannerActionLabel: 'Mark now',
        pendingClassId: null,
        classesMarked: 0,
        classesTotal: 0,
        studentsPresent: 0,
        studentsTotal: 0,
      ),
      todaySchedule: const [],
      pendingTasks: const [],
      classTeacher: null,
      quickActions: base.quickActions,
      aiInsight: base.aiInsight,
      studentsNeedingAttention: const [],
    );
  }

  static StudentDashboardData emptyStudentDashboard() {
    final base = StudentDashboardData.mock();
    return StudentDashboardData(
      studentName: base.studentName,
      greetingHeadline: base.greetingHeadline,
      greetingSubtitle: base.greetingSubtitle,
      classLabel: base.classLabel,
      unreadNotifications: 0,
      todaySchedule: const [],
      quickActions: base.quickActions,
      attendanceKpi: base.attendanceKpi,
      homeworkDue: const [],
      examReminder: base.examReminder,
      aiInsight: base.aiInsight,
    );
  }
}
