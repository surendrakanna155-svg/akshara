import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';

/// Maps PA-01 dashboard [actionId] values to GoRouter destinations.
void handleParentDashboardNavigation(BuildContext context, String actionId) {
  switch (actionId) {
    case 'pay_fee':
    case 'fees':
      context.go(RouteNames.parentFees);
    case 'attendance':
    case 'today_see_all':
      context.go(RouteNames.parentAttendance);
    case 'homework':
      // Future: /parent/homework
      break;
    case 'contact_teacher':
    case 'report_card':
    case 'notifications':
      context.push(RouteNames.parentNotifications);
    case 'ai_copilot':
    case 'profile':
    case 'child_switch':
    default:
      break;
  }
}
