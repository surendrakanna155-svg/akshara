import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/industry/industry_hub_screen.dart';

Widget industryHubRouteBuilder(BuildContext context, GoRouterState state) {
  return const IndustryHubScreen();
}

Widget industryFrameworkRouteBuilder(BuildContext context, GoRouterState state) {
  return const IndustryHubScreen(showFramework: true);
}
