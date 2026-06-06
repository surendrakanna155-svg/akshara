import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';

/// Maps TA-01 dashboard [actionId] values to GoRouter destinations.
void handleTeacherNavigation(BuildContext context, String actionId) {
  switch (actionId) {
    case 'mark_attendance':
    case 'staff_check_in':
    case 'staff_check_in_now':
      break;
    case 'create_homework':
      break;
    case 'timetable':
      break;
    case 'messages':
    case 'unread_messages':
      break;
    case 'hw_review':
      break;
    case 'notifications':
      context.push(RouteNames.parentNotifications);
    case 'class_teacher_dashboard':
    case 'ai_copilot':
    case 'profile':
    case 'home':
      break;
    default:
      if (actionId.startsWith('mark_attendance_') ||
          actionId.startsWith('class_')) {
        break;
      }
      break;
  }
}
