import 'package:flutter/foundation.dart';

import '../../router/route_names.dart';
import 'industry_type.dart';

@immutable
class IndustryCapability {
  const IndustryCapability({
    required this.industry,
    required this.modules,
    required this.dashboardRoutes,
    required this.widgetPack,
    required this.copilotContextKey,
  });

  final IndustryType industry;
  final List<String> modules;
  final List<String> dashboardRoutes;
  final String widgetPack;
  final String copilotContextKey;
}

/// Maps each [IndustryType] to modules, routes, widget packs, and copilot keys.
class IndustryCapabilityRegistry {
  const IndustryCapabilityRegistry._();

  static const capabilities = <IndustryType, IndustryCapability>{
    IndustryType.school: IndustryCapability(
      industry: IndustryType.school,
      modules: ['admissions', 'finance', 'sis', 'hr', 'management'],
      dashboardRoutes: [RouteNames.managementDashboard, RouteNames.financeDashboard],
      widgetPack: 'school',
      copilotContextKey: 'school_operations',
    ),
    IndustryType.salon: IndustryCapability(
      industry: IndustryType.salon,
      modules: ['salon', 'appointments', 'customers', 'services'],
      dashboardRoutes: [RouteNames.salonDashboard],
      widgetPack: 'salon',
      copilotContextKey: 'salon_business',
    ),
    IndustryType.hospital: IndustryCapability(
      industry: IndustryType.hospital,
      modules: ['healthcare', 'patients', 'appointments', 'practitioners'],
      dashboardRoutes: [RouteNames.healthcareDashboard],
      widgetPack: 'hospital',
      copilotContextKey: 'healthcare_clinical',
    ),
    IndustryType.restaurant: IndustryCapability(
      industry: IndustryType.restaurant,
      modules: ['restaurant', 'tables', 'orders', 'kitchen'],
      dashboardRoutes: [RouteNames.restaurantDashboard],
      widgetPack: 'restaurant',
      copilotContextKey: 'restaurant_hospitality',
    ),
    IndustryType.hostel: IndustryCapability(
      industry: IndustryType.hostel,
      modules: ['accommodation', 'residents', 'rooms', 'allocations'],
      dashboardRoutes: [RouteNames.accommodationDashboard, RouteNames.hostelDashboard],
      widgetPack: 'hostel',
      copilotContextKey: 'accommodation_residency',
    ),
  };

  static IndustryCapability forIndustry(IndustryType industry) =>
      capabilities[industry] ?? capabilities[IndustryType.school]!;

  static List<IndustryCapability> all() =>
      IndustryType.values.map(forIndustry).toList(growable: false);
}
