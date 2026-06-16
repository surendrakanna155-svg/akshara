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
    case 'staff_check_in':
    case 'staff_check_in_now':
      context.go(RouteNames.teacherAttendance);
    case 'create_homework':
      context.go(RouteNames.teacherHomeworkCreate);
      break;
    case 'hw_review':
    case 'homework':
      context.go(RouteNames.teacherHomework);
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
    case 'student_risk':
      if (actionId.startsWith('student_risk_')) {
        final id = actionId.replaceFirst('student_risk_', '');
        context.push(RouteNames.teacherStudentRisk(id));
      }
    case 'leave':
      context.go(RouteNames.teacherLeave);
    case 'notifications':
      context.push(RouteNames.parentNotifications);
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
      context.go(RouteNames.teacherDashboard);
    case 'home':
      context.go(RouteNames.teacherDashboard);
    default:
      if (actionId.startsWith('mark_attendance_')) {
        context.go(RouteNames.teacherAttendance);
      } else if (actionId.startsWith('class_')) {
        context.go(RouteNames.teacherTimetable);
      } else if (actionId.startsWith('thread_')) {
        context.push(RouteNames.teacherConversation(actionId));
      }
      break;
  }
}
