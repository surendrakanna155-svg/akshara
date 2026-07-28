import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/hr/staff_360/staff_360_screen.dart';
import 'route_names.dart';

/// Builds the Staff 360 dossier for an employee id.
Widget staff360RouteBuilder(BuildContext context, GoRouterState state) {
  final employeeId = state.pathParameters['employeeId'] ?? '';
  return Staff360Screen(employeeId: employeeId);
}

String staff360Path(String employeeId) => '${RouteNames.staff360}/$employeeId';

/// Navigates to the unified [Staff360Screen] for the given employee id.
void openStaff360(BuildContext context, String employeeId) {
  if (employeeId.trim().isEmpty) return;
  context.push(staff360Path(employeeId));
}
