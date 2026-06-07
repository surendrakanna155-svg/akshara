import '../../../features/control_center/control_center_models.dart';
import '../repository_query.dart';

/// Contract for platform control center data access (mock or API).
abstract class ControlCenterRepository {
  Future<ControlCenterDashboardData> getDashboard({required RepositoryQuery query});
  Future<List<PlatformSchool>> getSchools({required RepositoryQuery query});
  Future<ControlCenterSubscriptionsData> getSubscriptions({required RepositoryQuery query});
  Future<ControlCenterBillingData> getBilling({required RepositoryQuery query});
  Future<ControlCenterCrmData> getCrmPipeline({required RepositoryQuery query});
  Future<List<SupportTicket>> getSupportTickets({required RepositoryQuery query});
  Future<ControlCenterSuccessData> getCustomerSuccess({required RepositoryQuery query});
  Future<List<WhiteLabelConfig>> getWhiteLabelConfigs({required RepositoryQuery query});
  Future<ControlCenterAnalyticsData> getAnalytics({required RepositoryQuery query});
  Future<ControlCenterMonitoringData> getMonitoring({required RepositoryQuery query});
  Future<ControlCenterRolesData> getRoles({required RepositoryQuery query});
  Future<ControlCenterSettingsData> getSettings({required RepositoryQuery query});
}
