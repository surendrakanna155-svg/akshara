import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/route_names.dart';
import 'management_models.dart';

/// Default KPI drill targets when [ManagementKpi.drillRoute] is not set explicitly.
String? defaultManagementKpiDrillRoute(String kpiId) => switch (kpiId) {
      'revenue_mtd' => RouteNames.financeReports,
      'fee_defaulters' => RouteNames.financeDefaulters,
      'fee_collection' => RouteNames.financeDefaulters,
      'new_admissions' => RouteNames.managementAdmissions,
      'attendance' => RouteNames.studentSuccessIntelligence,
      'pass_rate' => RouteNames.examIntelligence,
      'at_risk' => RouteNames.examIntelligence,
      'pending_approvals' => RouteNames.managementTasks,
      _ => null,
    };

/// Navigates to the drill-down route for a management KPI tile.
void navigateManagementKpiDrill(BuildContext context, ManagementKpi kpi) {
  final route = kpi.drillRoute ?? defaultManagementKpiDrillRoute(kpi.id);
  if (route != null) {
    context.go(route);
  }
}

bool managementKpiIsDrillable(ManagementKpi kpi) {
  return (kpi.drillRoute ?? defaultManagementKpiDrillRoute(kpi.id)) != null;
}
