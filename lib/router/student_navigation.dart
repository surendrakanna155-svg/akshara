import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/copilot/copilot_navigation.dart';
import 'route_names.dart';

/// Maps ST-01 dashboard [actionId] values to GoRouter destinations.
void handleStudentNavigation(
  BuildContext context,
  String actionId, {
  WidgetRef? ref,
}) {
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
    case 'report_card':
      context.go(RouteNames.studentReportCard);
    case 'progress':
    case 'academic_progress':
      context.go(RouteNames.studentProgress);
    case 'notices':
      context.go(RouteNames.studentNotices);
    case 'profile':
      context.go(RouteNames.studentProfile);
    case 'notifications':
      context.push(RouteNames.parentNotifications);
    case 'join_class':
      context.go(RouteNames.studentTimetable);
    case 'ai_assistant':
    case 'ai_quiz':
      if (ref != null) {
        openAiPersonaAssistant(context, ref);
      } else {
        context.push(RouteNames.aiAssistant);
      }
    case 'home':
      context.go(RouteNames.studentDashboard);
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
