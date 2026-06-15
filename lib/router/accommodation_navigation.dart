import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/verticals/accommodation/accommodation_dashboard_screen.dart';
import '../features/verticals/accommodation/accommodation_intelligence_screen.dart';
import '../features/verticals/accommodation/resident_lifecycle_screen.dart';
import '../features/verticals/accommodation/occupancy_management_screen.dart';
import '../features/verticals/accommodation/room_allocation_screen.dart';

Widget accommodationDashboardRouteBuilder(BuildContext context, GoRouterState state) =>
    const AccommodationDashboardScreen();

Widget accommodationIntelligenceRouteBuilder(BuildContext context, GoRouterState state) =>
    const AccommodationIntelligenceScreen();

Widget accommodationResidentRouteBuilder(BuildContext context, GoRouterState state) =>
    const ResidentLifecycleScreen();

Widget accommodationRoomOccupancyRouteBuilder(BuildContext context, GoRouterState state) =>
    const OccupancyManagementScreen();

Widget accommodationAccommodationAllocationRouteBuilder(BuildContext context, GoRouterState state) =>
    const RoomAllocationScreen();
