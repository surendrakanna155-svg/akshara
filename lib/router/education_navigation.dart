import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/education/education_screen.dart';
import 'route_names.dart';

Widget educationRouteBuilder(BuildContext context, GoRouterState state) {
  return const EducationScreen();
}

String? educationRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.education) {
    return RouteNames.education;
  }
  return null;
}
