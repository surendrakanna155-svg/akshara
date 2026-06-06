import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admissions/applications/admissions_applications_screen.dart';
import '../features/admissions/approval/admissions_approval_screen.dart';
import '../features/admissions/dashboard/admissions_dashboard_screen.dart';
import '../features/admissions/documents/admissions_documents_screen.dart';
import '../features/admissions/enrollment/admissions_enrollment_screen.dart';
import '../features/admissions/fee_handoff/admissions_fee_handoff_screen.dart';
import '../features/admissions/leads/admissions_lead_detail_screen.dart';
import '../features/admissions/leads/admissions_leads_screen.dart';
import '../features/admissions/reports/admissions_reports_screen.dart';
import '../features/admissions/settings/admissions_settings_screen.dart';
import 'route_names.dart';

/// Redirects bare `/admissions` to the dashboard entry point.
String? admissionsRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.admissions) {
    return RouteNames.admissionsDashboard;
  }
  return null;
}

Widget admissionsDashboardRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AdmissionsDashboardScreen();
}

Widget admissionsLeadsRouteBuilder(BuildContext context, GoRouterState state) {
  return const AdmissionsLeadsScreen();
}

Widget admissionsLeadDetailRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  final leadId = state.pathParameters['leadId'] ?? '';
  return AdmissionsLeadDetailScreen(leadId: leadId);
}

Widget admissionsApplicationsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AdmissionsApplicationsScreen();
}

Widget admissionsEnrollmentRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AdmissionsEnrollmentScreen();
}

Widget admissionsDocumentsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AdmissionsDocumentsScreen();
}

Widget admissionsApprovalRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AdmissionsApprovalScreen();
}

Widget admissionsFeeHandoffRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AdmissionsFeeHandoffScreen();
}

Widget admissionsReportsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AdmissionsReportsScreen();
}

Widget admissionsSettingsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AdmissionsSettingsScreen();
}
