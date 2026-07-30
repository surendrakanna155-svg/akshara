import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/copilot/copilot_navigation.dart';
import 'route_names.dart';

/// Maps TA-01 dashboard [actionId] values to GoRouter destinations.
void handleTeacherNavigation(
  BuildContext context,
  String actionId, {
  WidgetRef? ref,
}) {
  switch (actionId) {
    case 'mark_attendance':
      context.go(RouteNames.teacherAttendance);
    // TCH-9 — the check-in card / "My attendance" tile opens the read-only
    // self-service attendance history (own check-ins), not the class roster.
    case 'my_attendance':
    case 'staff_check_in':
    case 'staff_check_in_now':
      context.go(RouteNames.teacherMyAttendance);
    case 'create_homework':
      context.go(RouteNames.teacherHomeworkCreate);
      break;
    // TCH-6 — the "HW to review" task lands on the still-unreviewed submissions.
    case 'hw_review':
      context.go('${RouteNames.teacherHomework}?filter=pending');
      break;
    case 'homework':
      context.go(RouteNames.teacherHomework);
      break;
    // TCH-2 — "Marks to enter" opens the exams marks-entry surface.
    case 'marks_pending':
      context.go(RouteNames.teacherExams);
      break;
    case 'timetable':
      context.go(RouteNames.teacherTimetable);
    case 'exams':
      context.go(RouteNames.teacherExams);
    case 'messages':
    case 'unread_messages':
      context.go(RouteNames.teacherMessages);
    case 'parent_communication':
      context.go(RouteNames.teacherParentCommunication);
    case 'leave':
      context.go(RouteNames.teacherLeave);
    case 'notifications':
      // F-128 — the teacher bell opens the teacher-scoped notifications inbox,
      // not the parent persona's route.
      context.push(RouteNames.teacherNotifications);
    case 'class_teacher_dashboard':
      context.go(RouteNames.teacherClassTeacherDashboard);
      break;
    case 'ai_copilot':
      if (ref != null) {
        openAiPersonaAssistant(context, ref);
      } else {
        context.push(RouteNames.aiAssistant);
      }
    case 'profile':
      // F-164 — the profile avatar opens the teacher profile, not Home.
      context.go(RouteNames.teacherProfile);
    case 'home':
      context.go(RouteNames.teacherDashboard);
    default:
      if (actionId.startsWith('schedule_attendance_')) {
        // TCH-1 — a today-schedule row → mark attendance for that class, using
        // the attendance screen's `?class=<label>` preselect.
        final label = actionId.replaceFirst('schedule_attendance_', '');
        context.go('${RouteNames.teacherAttendance}?class=$label');
      } else if (actionId.startsWith('mark_attendance_')) {
        context.go(RouteNames.teacherAttendance);
      } else if (actionId.startsWith('student_risk_')) {
        // F-163 — the dashboard "Students requiring attention → Review" tap
        // emits `student_risk_<sisStudentId>`; open that student's risk detail
        // (mirrors the class-teacher dashboard's RouteNames.teacherStudentRisk).
        final id = actionId.replaceFirst('student_risk_', '');
        context.push(RouteNames.teacherStudentRisk(id));
      } else if (actionId.startsWith('class_')) {
        context.go(RouteNames.teacherTimetable);
      } else if (actionId.startsWith('thread_')) {
        context.push(RouteNames.teacherConversation(actionId));
      }
      break;
  }
}
