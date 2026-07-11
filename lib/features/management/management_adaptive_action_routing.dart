import '../../router/route_names.dart';

/// Maps an Adaptive AI recommendation's (logical) deepLink — including the
/// W2.7 ops-module worklists (`recommendation_actions.ts`) — to the principal's
/// closest EXISTING management/module route. Pure + testable; the caller
/// performs the actual `context.go(...)`. Unknown/unmapped deep links fall
/// back to the management intelligence hub — the AI only ever navigated, it
/// never executed the underlying action.
String managementAdaptiveActionRoute(String deepLink) {
  // More specific than the generic '/finance' prefix below: the recovery call
  // queue IS the collection follow-up screen, not the finance overview tab.
  if (deepLink.startsWith('/finance/recovery')) return RouteNames.financeDefaulters;
  if (deepLink.startsWith('/finance')) return RouteNames.managementFinance;
  if (deepLink.startsWith('/inventory/stock')) return RouteNames.inventoryStock;
  if (deepLink.startsWith('/transport')) return RouteNames.transportVehicles;
  if (deepLink.startsWith('/hr')) return RouteNames.hrReports;
  if (deepLink.startsWith('/library')) return RouteNames.libraryOverdue;
  if (deepLink.startsWith('/analytics')) return RouteNames.managementAnalytics;
  if (deepLink.startsWith('/timetable')) return RouteNames.managementTimetable;
  if (deepLink.contains('approval')) return RouteNames.managementApprovals;
  return RouteNames.managementIntelligence;
}
