import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/employee/employee_platform_screen.dart';
import '../features/homework_intelligence/homework_intelligence_screen.dart';
import '../features/inventory_distribution/inventory_distribution_screen.dart';
import '../features/student_360/student_360_screen.dart';
import 'route_names.dart';

Widget homeworkIntelligenceRouteBuilder(BuildContext context, GoRouterState state) {
  return const HomeworkIntelligenceScreen();
}

Widget student360RouteBuilder(BuildContext context, GoRouterState state) {
  final studentId = state.pathParameters['studentId'] ?? 'student_1';
  return Student360Screen(studentId: studentId);
}

Widget employeePlatformRouteBuilder(BuildContext context, GoRouterState state) {
  return const EmployeePlatformScreen();
}

Widget inventoryDistributionRouteBuilder(BuildContext context, GoRouterState state) {
  return const InventoryDistributionScreen();
}

String student360Path(String studentId) => '${RouteNames.student360}/$studentId';
