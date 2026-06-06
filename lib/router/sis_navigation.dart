import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/sis/academic_assignment/sis_academic_assignment_screen.dart';
import '../features/sis/admissions_conversion/sis_admissions_conversion_screen.dart';
import '../features/sis/dashboard/sis_dashboard_screen.dart';
import '../features/sis/profile/sis_profile_screen.dart';
import '../features/sis/registry/sis_registry_screen.dart';
import 'route_names.dart';

String? sisRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.sis) {
    return RouteNames.sisDashboard;
  }
  return null;
}

Widget sisDashboardRouteBuilder(BuildContext context, GoRouterState state) {
  return const SisDashboardScreen();
}

Widget sisStudentsRouteBuilder(BuildContext context, GoRouterState state) {
  return const SisRegistryScreen();
}

Widget sisStudentDetailRouteBuilder(BuildContext context, GoRouterState state) {
  final studentId = state.pathParameters['studentId'] ?? '';
  return SisStudentProfileScreen(studentId: studentId);
}

Widget sisAcademicAssignmentRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const SisAcademicAssignmentScreen();
}

Widget sisAdmissionsConversionRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const SisAdmissionsConversionScreen();
}
