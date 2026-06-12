import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';

/// Maps TA-01 dashboard [actionId] values to GoRouter destinations.
void handleTeacherNavigation(BuildContext context, String actionId) {
  switch (actionId) {
    case 'mark_attendance':
    case 'staff_check_in':
    case 'staff_check_in_now':
      context.go(RouteNames.teacherAttendance);
    case 'create_homework':
    case 'hw_review':
    case 'homework':
      context.go(RouteNames.teacherHomework);
    case 'timetable':
      context.go(RouteNames.teacherTimetable);
    case 'exams':
      context.go(RouteNames.teacherExams);
    case 'messages':
    case 'unread_messages':
      context.go(RouteNames.teacherMessages);
    case 'leave':
      context.go(RouteNames.teacherLeave);
    case 'notifications':
      context.push(RouteNames.parentNotifications);
    case 'class_teacher_dashboard':
      context.go(RouteNames.teacherAttendance);
    case 'ai_copilot':
      context.push(RouteNames.teacherAssistant);
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
