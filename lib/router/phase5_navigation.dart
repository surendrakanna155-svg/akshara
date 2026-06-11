import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/employee/employee_360_screen.dart';
import '../features/memories/school_memories_screen.dart';
import '../features/operations/operations_hub_screen.dart';
import '../features/parent/experience/parent_experience_hub_screen.dart';
import '../features/promotion/achievement_promotion_screen.dart';
import 'route_names.dart';

Widget parentExperienceHubRouteBuilder(BuildContext context, GoRouterState state) {
  final studentId = state.uri.queryParameters['studentId'];
  final tabName = state.uri.queryParameters['tab'];
  final tabIndex = switch (tabName) {
    'academics' => 1,
    'attendance' => 2,
    'inventory' => 3,
    'communication' => 4,
    'guidance' => 5,
    _ => 0,
  };
  return ParentExperienceHubScreen(studentId: studentId, initialTab: tabIndex);
}

Widget employee360RouteBuilder(BuildContext context, GoRouterState state) {
  final employeeId = state.pathParameters['employeeId'] ?? 'emp_1';
  return Employee360Screen(employeeId: employeeId);
}

Widget operationsHubRouteBuilder(BuildContext context, GoRouterState state) {
  return const OperationsHubScreen();
}

Widget schoolMemoriesRouteBuilder(BuildContext context, GoRouterState state) {
  return const SchoolMemoriesScreen();
}

Widget achievementPromotionRouteBuilder(BuildContext context, GoRouterState state) {
  return const AchievementPromotionScreen();
}

String employee360Path(String employeeId) => '${RouteNames.employee360}/$employeeId';
