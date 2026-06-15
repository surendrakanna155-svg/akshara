import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dynamic_widgets/dynamic_widget_layout_editor_screen.dart';
import '../features/dynamic_widgets/dynamic_widget_registry_screen.dart';
import '../features/dynamic_widgets/dynamic_widget_runtime_screen.dart';

Widget dynamicWidgetRegistryRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const DynamicWidgetRegistryScreen();
}

Widget dynamicWidgetLayoutRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const DynamicWidgetLayoutEditorScreen();
}

Widget dynamicWidgetRuntimeRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const DynamicWidgetRuntimeScreen();
}
