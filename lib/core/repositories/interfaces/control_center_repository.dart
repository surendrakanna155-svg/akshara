import '../../../features/platform/control_center/control_center_models.dart';
import '../../../features/platform/control_center/control_center_requests.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for platform control center data access (mock or API).
abstract class ControlCenterRepository {
  Future<ControlCenterDashboardData> getDashboard({required RepositoryQuery query});
  Future<PaginatedResult<PlatformSchool>> getSchools({required RepositoryQuery query});
  Future<ControlCenterSubscriptionsData> getSubscriptions({required RepositoryQuery query});
  Future<ControlCenterBillingData> getBilling({required RepositoryQuery query});
  Future<ControlCenterCrmData> getCrmPipeline({required RepositoryQuery query});
  Future<PaginatedResult<SupportTicket>> getSupportTickets({required RepositoryQuery query});
  Future<ControlCenterSuccessData> getCustomerSuccess({required RepositoryQuery query});
  Future<PaginatedResult<WhiteLabelConfig>> getWhiteLabelConfigs({required RepositoryQuery query});
  Future<ControlCenterAnalyticsData> getAnalytics({required RepositoryQuery query});
  Future<ControlCenterMonitoringData> getMonitoring({required RepositoryQuery query});
  Future<ControlCenterRolesData> getRoles({required RepositoryQuery query});
  Future<ControlCenterSettingsData> getSettings({required RepositoryQuery query});

  Future<ControlCenterProvidersData> getProviders({required RepositoryQuery query});

  Future<void> saveProvider({
    required RepositoryQuery query,
    required String providerCategory,
    required String providerName,
    String? credential,
    bool isActive = true,
    bool isPrimary = false,
    Map<String, dynamic>? config,
  });

  Future<void> setFeatureEnablement({
    required RepositoryQuery query,
    required String schoolId,
    required String featureKey,
    required bool enabled,
  });

  Future<PlatformSchool> createSchool({
    required RepositoryQuery query,
    required CreateSchoolRequest request,
  });

  Future<CrmDeal> createLead({
    required RepositoryQuery query,
    required CreateCrmLeadRequest request,
  });
}
