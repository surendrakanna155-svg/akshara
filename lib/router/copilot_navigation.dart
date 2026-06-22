import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/copilot/content/ai_content_screen.dart';
import '../features/copilot/copilot_screen.dart';
import '../features/copilot/settings/ai_assistant_settings_screen.dart';
import '../features/copilot/persona/copilot_persona_shell_screen.dart';
import 'route_names.dart';

Widget copilotRouteBuilder(BuildContext context, GoRouterState state) {
  return const CopilotScreen();
}

Widget aiContentRouteBuilder(BuildContext context, GoRouterState state) {
  return const AiContentScreen();
}

Widget aiAssistantRouteBuilder(BuildContext context, GoRouterState state) {
  return const CopilotPersonaShellScreen();
}

Widget aiAssistantSettingsRouteBuilder(BuildContext context, GoRouterState state) {
  return const AiAssistantSettingsScreen();
}

String? copilotRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.copilot) {
    return RouteNames.copilot;
  }
  return null;
}
