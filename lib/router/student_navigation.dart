import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';

/// Maps ST-01 dashboard [actionId] values to GoRouter destinations.
void handleStudentNavigation(BuildContext context, String actionId) {
  switch (actionId) {
    case 'attendance':
      context.go(RouteNames.studentAttendance);
    case 'full_schedule':
    case 'period_list':
      context.go(RouteNames.studentTimetable);
    case 'homework_list':
    case 'submit_homework':
    case 'homework':
      context.go(RouteNames.studentHomework);
    case 'exam_results':
    case 'exams':
      context.go(RouteNames.studentExams);
    case 'notices':
      context.go(RouteNames.studentNotices);
    case 'profile':
      context.go(RouteNames.studentProfile);
    case 'notifications':
      context.push(RouteNames.parentNotifications);
    case 'join_class':
    case 'ai_assistant':
    case 'ai_quiz':
    case 'home':
      break;
    default:
      if (actionId.startsWith('homework_')) {
        context.go(RouteNames.studentHomework);
      } else if (actionId.startsWith('period_')) {
        context.go(RouteNames.studentTimetable);
      } else if (actionId.startsWith('exam_')) {
        context.go(RouteNames.studentExams);
      }
      break;
  }
}
