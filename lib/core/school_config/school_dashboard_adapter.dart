import '../../features/management/management_models.dart';
import '../../features/parent/dashboard/parent_dashboard_provider.dart';
import 'school_capability_registry.dart';
import 'school_configuration_models.dart';

ManagementDashboardData adaptManagementDashboard(
  ManagementDashboardData data,
  SchoolCapabilities capabilities,
) {
  return ManagementDashboardData(
    kpis: data.kpis
        .where((kpi) => SchoolCapabilityRegistry.isKpiEnabled(kpi.id, capabilities))
        .toList(growable: false),
    revenueTrend: data.revenueTrend,
    expenseBreakdown: data.expenseBreakdown,
    admissionsSnapshot: data.admissionsSnapshot,
    feeSnapshot: data.feeSnapshot,
    approvalQueue: data.approvalQueue
        .where((item) => _approvalEnabled(item.sourceModuleRoute, capabilities))
        .toList(growable: false),
    aiInsight: data.aiInsight,
  );
}

bool _approvalEnabled(String? route, SchoolCapabilities capabilities) {
  if (route == null) return true;
  if (route.contains('transport')) return capabilities.transport;
  if (route.contains('hostel')) return capabilities.hostel;
  if (route.contains('library')) return capabilities.library;
  if (route.contains('inventory')) return capabilities.inventory;
  return true;
}

ParentDashboardData adaptParentDashboard(
  ParentDashboardData data,
  SchoolCapabilities capabilities,
) {
  return ParentDashboardData(
    childName: data.childName,
    childClass: data.childClass,
    greetingEyebrow: data.greetingEyebrow,
    greetingHeadline: data.greetingHeadline,
    schoolName: data.schoolName,
    statusChips: data.statusChips,
    quickActions: data.quickActions,
    todaySummary: data.todaySummary,
    notices: capabilities.transport
        ? data.notices
        : data.notices
            .where((notice) => !notice.title.toLowerCase().contains('transport'))
            .toList(growable: false),
    events: data.events,
    aiInsight: data.aiInsight,
    unreadNotifications: data.unreadNotifications,
  );
}
