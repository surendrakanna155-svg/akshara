import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/intelligence/exam/exam_intelligence_screen.dart';
import '../features/intelligence/intelligence_screen.dart';
import '../features/intelligence/student_success/student_success_screen.dart';
import '../features/intelligence/teacher_effectiveness/teacher_effectiveness_screen.dart';
import '../features/intelligence/trust/trust_intelligence_hub_screen.dart';
import 'route_names.dart';

Widget intelligenceRouteBuilder(BuildContext context, GoRouterState state) {
  return const IntelligenceScreen();
}

Widget studentSuccessIntelligenceRouteBuilder(BuildContext context, GoRouterState state) {
  return const StudentSuccessScreen();
}

Widget examIntelligenceRouteBuilder(BuildContext context, GoRouterState state) {
  return const ExamIntelligenceScreen();
}

Widget teacherEffectivenessRouteBuilder(BuildContext context, GoRouterState state) {
  return const TeacherEffectivenessScreen();
}

Widget organizationIntelligenceRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const TrustIntelligenceHubScreen();
}

String? intelligenceRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.intelligence) {
    return RouteNames.intelligence;
  }
  return null;
}
