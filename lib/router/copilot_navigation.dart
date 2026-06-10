import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/copilot/copilot_screen.dart';
import 'route_names.dart';

Widget copilotRouteBuilder(BuildContext context, GoRouterState state) {
  return const CopilotScreen();
}

String? copilotRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.copilot) {
    return RouteNames.copilot;
  }
  return null;
}
