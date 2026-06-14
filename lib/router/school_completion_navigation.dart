import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/school_completion/branding_screen.dart';
import '../features/school_completion/communication_analytics_screen.dart';
import '../features/school_completion/communication_delivery_screen.dart';
import '../features/communication/broadcast_admin_screen.dart';
import '../features/school_completion/academic_progress_screen.dart';
import '../features/school_completion/lesson_analytics_screen.dart';
import '../features/school_completion/lesson_logs_screen.dart';
import '../features/school_completion/parent_activation_dashboard_screen.dart';
import '../features/school_completion/pilot_dashboard_screen.dart';
import '../features/school_completion/room_allocation_screen.dart';
import '../features/school_completion/school_completion_hub_screen.dart';
import '../features/school_completion/subject_assignment_screen.dart';
import '../features/school_completion/substitute_manager_screen.dart';
import '../features/school_completion/subjects_screen.dart';
import '../features/school_completion/syllabus_automation_screen.dart';
import '../features/school_completion/teacher_reassignment_screen.dart';
import '../features/school_completion/timetable_automation_screen.dart';
import '../features/school_completion/timetable_intelligence_screen.dart';
import '../features/school_completion/timetable_optimization_screen.dart';
import '../features/school_completion/whatsapp_provider_screen.dart';

Widget schoolCompletionHubRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const SchoolCompletionHubScreen();
}

Widget subjectsManagementRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const SubjectsScreen();
}

Widget lessonLogsRouteBuilder(BuildContext context, GoRouterState state) {
  return const LessonLogsScreen();
}

Widget timetableAutomationRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const TimetableAutomationScreen();
}

Widget schoolBrandingRouteBuilder(BuildContext context, GoRouterState state) {
  return const BrandingScreen();
}

Widget whatsAppProviderRouteBuilder(BuildContext context, GoRouterState state) {
  return const WhatsAppProviderScreen();
}

Widget subjectAssignmentsRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const SubjectAssignmentScreen();
}

Widget lessonAnalyticsRouteBuilder(BuildContext context, GoRouterState state) {
  return const LessonAnalyticsScreen();
}

Widget timetableOptimizationRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const TimetableOptimizationScreen();
}

Widget substituteManagerRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const SubstituteManagerScreen();
}

Widget teacherReassignmentRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const TeacherReassignmentScreen();
}

Widget communicationDeliveryRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const CommunicationDeliveryScreen();
}

Widget communicationBroadcastAdminRouteBuilder(
  BuildContext context,
  GoRouterState state,
) {
  return const BroadcastAdminScreen();
}

Widget communicationAnalyticsRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const CommunicationAnalyticsScreen();
}

Widget pilotDashboardRouteBuilder(BuildContext context, GoRouterState state) {
  return const PilotDashboardScreen();
}

Widget syllabusAutomationRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const SyllabusAutomationScreen();
}

Widget academicProgressRouteBuilder(BuildContext context, GoRouterState state) {
  return const AcademicProgressScreen();
}

Widget timetableIntelligenceRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const TimetableIntelligenceScreen();
}

Widget parentActivationDashboardRouteBuilder(
    BuildContext context, GoRouterState state) {
  return const ParentActivationDashboardScreen();
}

Widget roomAllocationRouteBuilder(BuildContext context, GoRouterState state) {
  return const RoomAllocationScreen();
}
