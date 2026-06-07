import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/alumni/campaigns/alumni_campaigns_screen.dart';
import '../features/alumni/dashboard/alumni_dashboard_screen.dart';
import '../features/alumni/donations/alumni_donations_screen.dart';
import '../features/alumni/events/alumni_events_screen.dart';
import '../features/alumni/mentorship/alumni_mentorship_screen.dart';
import '../features/alumni/profile/alumni_profile_screen.dart';
import '../features/alumni/registry/alumni_registry_screen.dart';
import '../features/alumni/reports/alumni_reports_screen.dart';
import '../features/alumni/settings/alumni_settings_screen.dart';
import 'route_names.dart';

String? alumniRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.alumni) {
    return RouteNames.alumniDashboard;
  }
  return null;
}

Widget alumniDashboardRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AlumniDashboardScreen();
}

Widget alumniRegistryRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AlumniRegistryScreen();
}

Widget alumniProfileRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  final alumniId = state.pathParameters['alumniId'] ?? '';
  return AlumniProfileScreen(alumniId: alumniId);
}

Widget alumniEventsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AlumniEventsScreen();
}

Widget alumniDonationsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AlumniDonationsScreen();
}

Widget alumniCampaignsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AlumniCampaignsScreen();
}

Widget alumniMentorshipRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AlumniMentorshipScreen();
}

Widget alumniReportsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AlumniReportsScreen();
}

Widget alumniSettingsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const AlumniSettingsScreen();
}
