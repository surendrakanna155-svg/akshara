import '../../../features/director/director_models.dart';
import '../repository_query.dart';

abstract class DirectorRepository {
  Future<DirectorDashboardData> getExecutiveDashboard({
    required RepositoryQuery query,
  });

  Future<List<DirectorSchoolRow>> getMultiSchoolOverview({
    required RepositoryQuery query,
  });

  /// DIR-2 — consolidated collection report: per-school fee% + billed/collected/
  /// outstanding money and org totals. GET /director/collections.
  Future<DirectorCollectionReport> getCollectionReport({
    required RepositoryQuery query,
  });

  /// DIR-D1 — audited, read-only per-school drill-down snapshot (school-level
  /// aggregates only, no student/parent PII). GET /director/schools/{id}/snapshot.
  Future<DirectorSchoolSnapshot> getSchoolSnapshot({
    required RepositoryQuery query,
    required String schoolId,
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

  Future<List<DirectorMetricInput>> getMetricInputs({
    required RepositoryQuery query,
  });

  Future<DirectorMetricInput> saveMetricInput({
    required RepositoryQuery query,
    required DirectorMetricInputDraft draft,
  });

  Future<DirectorBoardPack> exportReport({
    required RepositoryQuery query,
    required String reportId,
  });
}
