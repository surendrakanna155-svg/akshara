import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/verticals/restaurant/restaurant_dashboard_screen.dart';
import '../features/verticals/restaurant/hospitality_intelligence_screen.dart';
import '../features/verticals/restaurant/table_management_screen.dart';
import '../features/verticals/restaurant/orders_screen.dart';
import '../features/verticals/restaurant/kitchen_workflow_screen.dart';

Widget restaurantDashboardRouteBuilder(BuildContext context, GoRouterState state) =>
    const RestaurantDashboardScreen();

Widget restaurantIntelligenceRouteBuilder(BuildContext context, GoRouterState state) =>
    const HospitalityIntelligenceScreen();

Widget restaurantRestaurantTableRouteBuilder(BuildContext context, GoRouterState state) =>
    const TableManagementScreen();

Widget restaurantRestaurantOrderRouteBuilder(BuildContext context, GoRouterState state) =>
    const OrdersScreen();

Widget restaurantKitchenTicketRouteBuilder(BuildContext context, GoRouterState state) =>
    const KitchenWorkflowScreen();
