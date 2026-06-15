import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/verticals/healthcare/healthcare_dashboard_screen.dart';
import '../features/verticals/healthcare/healthcare_intelligence_screen.dart';
import '../features/verticals/healthcare/patient_registry_screen.dart';
import '../features/verticals/healthcare/appointment_workflow_screen.dart';
import '../features/verticals/healthcare/practitioner_management_screen.dart';

Widget healthcareDashboardRouteBuilder(BuildContext context, GoRouterState state) =>
    const HealthcareDashboardScreen();

Widget healthcareIntelligenceRouteBuilder(BuildContext context, GoRouterState state) =>
    const HealthcareIntelligenceScreen();

Widget healthcarePatientRouteBuilder(BuildContext context, GoRouterState state) =>
    const PatientRegistryScreen();

Widget healthcareAppointmentRouteBuilder(BuildContext context, GoRouterState state) =>
    const AppointmentWorkflowScreen();

Widget healthcarePractitionerRouteBuilder(BuildContext context, GoRouterState state) =>
    const PractitionerManagementScreen();
