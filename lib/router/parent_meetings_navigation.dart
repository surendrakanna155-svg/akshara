import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/school_build_scope.dart';
import '../features/parent_meetings/parent_meetings_screen.dart';
import 'route_guards.dart';

Widget parentMeetingsRouteBuilder(BuildContext context, GoRouterState state) {
  // Gated OFF until the PTM backend ships (CORE-1/PAR-4): the screen was
  // mock-only and lost edits on restart, so it is hidden via SchoolBuildScope.
  if (SchoolBuildScope.isRouteHidden(state.uri.path)) {
    return const AccessDeniedScreen();
  }
  return const ParentMeetingsScreen();
}
