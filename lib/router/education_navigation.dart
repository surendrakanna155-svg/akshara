import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/school_build_scope.dart';
import '../features/education/education_screen.dart';
import 'route_guards.dart';
import 'route_names.dart';

/// Education Suite (Question Papers + Question Bank + Homework + Remarks).
///
/// V1 SCOPE (owner decision, 2026-07-28): the Question Paper / QIE engine does
/// NOT ship in Version 1 — the generation engine is still owner/data-gated (the
/// certified question bank is empty), so the tab would demo an incomplete
/// feature. The whole surface is gated OFF via [SchoolBuildScope] rather than
/// deleted; V2 ships it with Navodaya / IIT-JEE / NEET / regular-school papers
/// and AI-assisted generation.
///
/// Nothing is lost by hiding this route: Homework and Remarks — the two tabs in
/// here that are actually complete — have their own first-class routes for every
/// persona (`/teacher/homework`, `/parent/homework`, `/student/homework`), so no
/// working capability is removed from any user.
///
/// TO RESTORE IN V2: delete the `RouteNames.education` entry from
/// [SchoolBuildScope.hiddenRoutePrefixes]. This builder then serves the screen
/// again unchanged — no other code needs to move.
Widget educationRouteBuilder(BuildContext context, GoRouterState state) {
  if (SchoolBuildScope.isRouteHidden(state.uri.path)) {
    return const AccessDeniedScreen();
  }
  return const EducationScreen();
}

String? educationRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.education) {
    return RouteNames.education;
  }
  return null;
}
