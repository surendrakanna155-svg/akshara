import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import 'management_models.dart';

/// Routes management AI insight card actions to module intelligence surfaces.
void navigateManagementInsightAction(
  BuildContext context,
  ManagementScreen screen,
) {
  final route = switch (screen) {
    ManagementScreen.dashboard => RouteNames.managementTasks,
    ManagementScreen.analytics => RouteNames.studentSuccessIntelligence,
    ManagementScreen.admissions => RouteNames.managementAdmissions,
    ManagementScreen.finance => RouteNames.financeDefaulters,
    ManagementScreen.academics => RouteNames.examIntelligence,
    ManagementScreen.performance => RouteNames.teacherEffectiveness,
    ManagementScreen.tasks => RouteNames.managementIntelligence,
    ManagementScreen.workflowAutomation => RouteNames.managementWorkflowAutomation,
    ManagementScreen.settings => RouteNames.managementSettings,
  };
  context.go(route);
}
