import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/verticals/salon/salon_dashboard_screen.dart';
import '../features/verticals/salon/business_intelligence_screen.dart';
import '../features/verticals/salon/customer_registry_screen.dart';
import '../features/verticals/salon/appointment_scheduling_screen.dart';
import '../features/verticals/salon/service_tracking_screen.dart';

Widget salonDashboardRouteBuilder(BuildContext context, GoRouterState state) =>
    const SalonDashboardScreen();

Widget salonIntelligenceRouteBuilder(BuildContext context, GoRouterState state) =>
    const BusinessIntelligenceScreen();

Widget salonSalonCustomerRouteBuilder(BuildContext context, GoRouterState state) =>
    const CustomerRegistryScreen();

Widget salonSalonAppointmentRouteBuilder(BuildContext context, GoRouterState state) =>
    const AppointmentSchedulingScreen();

Widget salonSalonServiceRouteBuilder(BuildContext context, GoRouterState state) =>
    const ServiceTrackingScreen();
