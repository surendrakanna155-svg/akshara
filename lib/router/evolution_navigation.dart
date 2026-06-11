import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/evolution/dynamic_dashboard_screen.dart';
import '../features/evolution/growth_platform_screen.dart';
import '../features/evolution/parent_insights_screen.dart';
import '../features/evolution/principal_command_screen.dart';
import '../features/evolution/setup_wizard_screen.dart';
import '../features/evolution/teacher_assistant_screen.dart';
import 'route_names.dart';

Widget setupWizardRouteBuilder(BuildContext context, GoRouterState state) {
  return const SetupWizardScreen();
}

Widget dynamicDashboardRouteBuilder(BuildContext context, GoRouterState state) {
  return const DynamicDashboardScreen();
}

Widget teacherAssistantRouteBuilder(BuildContext context, GoRouterState state) {
  return const TeacherAssistantScreen();
}

Widget parentInsightsRouteBuilder(BuildContext context, GoRouterState state) {
  return const ParentInsightsScreen();
}

Widget principalCommandRouteBuilder(BuildContext context, GoRouterState state) {
  return const PrincipalCommandScreen();
}

Widget growthPlatformRouteBuilder(BuildContext context, GoRouterState state) {
  return const GrowthPlatformScreen();
}

String? evolutionRedirect(GoRouterState state) {
  final path = state.uri.path;
  if (path == RouteNames.setupWizard ||
      path == RouteNames.dynamicDashboard ||
      path == RouteNames.teacherAssistant ||
      path == RouteNames.parentInsights ||
      path == RouteNames.principalCommand ||
      path == RouteNames.growthPlatform) {
    return path;
  }
  return null;
}
