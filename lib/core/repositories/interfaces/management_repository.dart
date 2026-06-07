import '../../../features/management/management_models.dart';
import '../repository_query.dart';

/// Contract for management portal data access (mock or API).
abstract class ManagementRepository {
  Future<ManagementDashboardData> getDashboard({required RepositoryQuery query});
  Future<ManagementAnalyticsData> getAnalytics({required RepositoryQuery query});
  Future<ManagementAdmissionsFunnelData> getAdmissionsFunnel({required RepositoryQuery query});
  Future<ManagementFinancialHealthData> getFinancialHealth({required RepositoryQuery query});
  Future<ManagementAcademicHealthData> getAcademicHealth({required RepositoryQuery query});
  Future<ManagementPerformanceData> getSchoolPerformance({required RepositoryQuery query});
  Future<ManagementTasksData> getTasksAndApprovals({required RepositoryQuery query});
  Future<ManagementSettingsData> getSettings({required RepositoryQuery query});
}
