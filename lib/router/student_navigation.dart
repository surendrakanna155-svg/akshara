import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';

/// Maps ST-01 dashboard [actionId] values to GoRouter destinations.
void handleStudentNavigation(BuildContext context, String actionId) {
  switch (actionId) {
    case 'full_schedule':
    case 'join_class':
    case 'submit_homework':
    case 'homework_list':
    case 'attendance':
    case 'exam_results':
    case 'ai_assistant':
    case 'ai_quiz':
    case 'profile':
    case 'home':
      break;
    case 'notifications':
      context.push(RouteNames.parentNotifications);
    default:
      if (actionId.startsWith('homework_') ||
          actionId.startsWith('period_') ||
          actionId.startsWith('exam_')) {
        break;
      }
      break;
  }
}
