import '../../../../features/director/director_models.dart';
import '../../interfaces/director_repository.dart';
import '../../repository_query.dart';
import '../api_exception.dart';

/// API wiring stub for Director module until remote datasource is connected.
class ApiDirectorRepository implements DirectorRepository {
  const ApiDirectorRepository();

  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApiDirectorRepository', method);
  }

  @override
  Future<DirectorComplianceItem> acknowledgeCompliance({
    required RepositoryQuery query,
    required String complianceId,
  }) async {
    _notConnected('acknowledgeCompliance');
  }

  @override
  Future<String> exportReport({
    required RepositoryQuery query,
    required String reportId,
  }) async {
    _notConnected('exportReport');
  }

  @override
  Future<String> generateExecutiveSummary({
    required RepositoryQuery query,
    required String focusArea,
  }) async {
    _notConnected('generateExecutiveSummary');
  }

  @override
  Future<DirectorAdmissionsSnapshot> getAdmissionsPerformance({
    required RepositoryQuery query,
  }) async {
    _notConnected('getAdmissionsPerformance');
  }

  @override
  Future<List<DirectorComplianceItem>> getComplianceMonitoring({
    required RepositoryQuery query,
  }) async {
    _notConnected('getComplianceMonitoring');
  }

  @override
  Future<DirectorDashboardData> getExecutiveDashboard({
    required RepositoryQuery query,
  }) async {
    _notConnected('getExecutiveDashboard');
  }

  @override
  Future<DirectorGrowthSnapshot> getGrowthAnalytics({
    required RepositoryQuery query,
  }) async {
    _notConnected('getGrowthAnalytics');
  }

  @override
  Future<DirectorMarketingSnapshot> getMarketingPerformance({
    required RepositoryQuery query,
  }) async {
    _notConnected('getMarketingPerformance');
  }

  @override
  Future<List<DirectorSchoolRow>> getMultiSchoolOverview({
    required RepositoryQuery query,
  }) async {
    _notConnected('getMultiSchoolOverview');
  }

  @override
  Future<DirectorGrowthSnapshot> getPortfolioAnalytics({
    required RepositoryQuery query,
  }) async {
    _notConnected('getPortfolioAnalytics');
  }

  @override
  Future<DirectorRevenueSnapshot> getRevenueOverview({
    required RepositoryQuery query,
  }) async {
    _notConnected('getRevenueOverview');
  }

  @override
  Future<List<DirectorReportItem>> getStrategicReports({
    required RepositoryQuery query,
  }) async {
    _notConnected('getStrategicReports');
  }
}
