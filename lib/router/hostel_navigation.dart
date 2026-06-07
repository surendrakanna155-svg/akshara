import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/hostel/attendance/hostel_attendance_screen.dart';
import '../features/hostel/dashboard/hostel_dashboard_screen.dart';
import '../features/hostel/leave/hostel_leave_screen.dart';
import '../features/hostel/mess/hostel_mess_screen.dart';
import '../features/hostel/reports/hostel_reports_screen.dart';
import '../features/hostel/rooms/hostel_rooms_screen.dart';
import '../features/hostel/students/hostel_students_screen.dart';
import '../features/hostel/visitors/hostel_visitors_screen.dart';
import 'route_names.dart';

String? hostelRootRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == RouteNames.hostel) {
    return RouteNames.hostelDashboard;
  }
  return null;
}

Widget hostelDashboardRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const HostelDashboardScreen();
}

Widget hostelStudentsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const HostelStudentsScreen();
}

Widget hostelRoomsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const HostelRoomsScreen();
}

Widget hostelAttendanceRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const HostelAttendanceScreen();
}

Widget hostelLeaveRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const HostelLeaveScreen();
}

Widget hostelMessRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const HostelMessScreen();
}

Widget hostelVisitorsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const HostelVisitorsScreen();
}

Widget hostelReportsRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const HostelReportsScreen();
}
