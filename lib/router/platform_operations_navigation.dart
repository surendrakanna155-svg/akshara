import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/platform_operations/platform_operations_hub_screen.dart';

int _initialTabFromRoute(GoRouterState state) {
  final tabParam = state.uri.queryParameters['tab'];
  if (tabParam != null) {
    return int.tryParse(tabParam) ?? 0;
  }
  switch (state.uri.path) {
    case '/platform-operations/alerts':
      return 5;
    case '/platform-operations/security':
      return 6;
    case '/platform-operations/tenant-isolation':
      return 7;
    case '/platform-operations/readiness':
      return 8;
    default:
      return 0;
  }
}

Widget platformOperationsHubRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return PlatformOperationsHubScreen(
    initialTab: _initialTabFromRoute(state),
  );
}
