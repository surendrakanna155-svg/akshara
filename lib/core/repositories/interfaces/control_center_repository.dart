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

  /// PRC-A Batch 3 — AI credit wallet balance + recent ledger (`viewAiWallet`).
  Future<AiWalletData> getAiWallet({required RepositoryQuery query});

  /// Grants a signed credit-ledger entry ('top_up' | 'adjustment' | 'expiry')
  /// and returns the resulting balance (`manageAiCredits`, superAdmin only).
  Future<AiWalletData> grantAiCredits({
    required RepositoryQuery query,
    required String entryType,
    required int units,
    required String reason,
    String? externalRef,
  });

  /// PRC-A Batch 4 — the org's cumulative storage usage + plan limit
  /// (`viewStorageQuota`). Read-only: usage is written internally by the
  /// upload/delete paths, not through a client mutation.
  Future<StorageQuotaData> getStorageQuota({required RepositoryQuery query});
}
