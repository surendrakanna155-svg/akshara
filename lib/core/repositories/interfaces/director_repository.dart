import '../../../features/director/director_models.dart';
import '../repository_query.dart';

abstract class DirectorRepository {
  Future<DirectorDashboardData> getExecutiveDashboard({
    required RepositoryQuery query,
  });

  Future<List<DirectorSchoolRow>> getMultiSchoolOverview({
    required RepositoryQuery query,
  });

  Future<DirectorGrowthSnapshot> getPortfolioAnalytics({
    required RepositoryQuery query,
  });

  Future<DirectorRevenueSnapshot> getRevenueOverview({
    required RepositoryQuery query,
  });

  Future<DirectorGrowthSnapshot> getGrowthAnalytics({
    required RepositoryQuery query,
  });

  Future<DirectorMarketingSnapshot> getMarketingPerformance({
    required RepositoryQuery query,
  });

  Future<DirectorAdmissionsSnapshot> getAdmissionsPerformance({
    required RepositoryQuery query,
  });

  Future<List<DirectorComplianceItem>> getComplianceMonitoring({
    required RepositoryQuery query,
  });

  Future<List<DirectorReportItem>> getStrategicReports({
    required RepositoryQuery query,
  });

  Future<String> generateExecutiveSummary({
    required RepositoryQuery query,
    required String focusArea,
  });

  Future<DirectorComplianceItem> acknowledgeCompliance({
    required RepositoryQuery query,
    required String complianceId,
  });

  Future<String> exportReport({
    required RepositoryQuery query,
    required String reportId,
  });
}
