import '../../interfaces/director_repository.dart';
import '../../mock/mock_director_repository.dart';
import '../../repository_query.dart';
import '../../../../features/director/director_models.dart';
import 'api_director_repository.dart';
import '../hybrid_write_fallback.dart';

/// API reads with mock fallback when API is disconnected.
class HybridDirectorRepository implements DirectorRepository {
  HybridDirectorRepository({
    required ApiDirectorRepository api,
    required MockDirectorRepository mock,
  })  : _api = api,
        _mock = mock;

  final ApiDirectorRepository _api;
  final MockDirectorRepository _mock;

  @override
  Future<DirectorDashboardData> getExecutiveDashboard({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getExecutiveDashboard(query: query),
        mockCall: () => _mock.getExecutiveDashboard(query: query),
      );

  @override
  Future<List<DirectorSchoolRow>> getMultiSchoolOverview({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getMultiSchoolOverview(query: query),
        mockCall: () => _mock.getMultiSchoolOverview(query: query),
      );

  @override
  Future<DirectorGrowthSnapshot> getPortfolioAnalytics({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getPortfolioAnalytics(query: query),
        mockCall: () => _mock.getPortfolioAnalytics(query: query),
      );

  @override
  Future<DirectorRevenueSnapshot> getRevenueOverview({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getRevenueOverview(query: query),
        mockCall: () => _mock.getRevenueOverview(query: query),
      );

  @override
  Future<DirectorGrowthSnapshot> getGrowthAnalytics({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getGrowthAnalytics(query: query),
        mockCall: () => _mock.getGrowthAnalytics(query: query),
      );

  @override
  Future<DirectorMarketingSnapshot> getMarketingPerformance({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getMarketingPerformance(query: query),
        mockCall: () => _mock.getMarketingPerformance(query: query),
      );

  @override
  Future<DirectorAdmissionsSnapshot> getAdmissionsPerformance({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getAdmissionsPerformance(query: query),
        mockCall: () => _mock.getAdmissionsPerformance(query: query),
      );

  @override
  Future<List<DirectorComplianceItem>> getComplianceMonitoring({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getComplianceMonitoring(query: query),
        mockCall: () => _mock.getComplianceMonitoring(query: query),
      );

  @override
  Future<List<DirectorReportItem>> getStrategicReports({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getStrategicReports(query: query),
        mockCall: () => _mock.getStrategicReports(query: query),
      );

  @override
  Future<String> generateExecutiveSummary({
    required RepositoryQuery query,
    required String focusArea,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.generateExecutiveSummary(
          query: query,
          focusArea: focusArea,
        ),
        mockCall: () => _mock.generateExecutiveSummary(
          query: query,
          focusArea: focusArea,
        ),
      );

  @override
  Future<DirectorComplianceItem> acknowledgeCompliance({
    required RepositoryQuery query,
    required String complianceId,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.acknowledgeCompliance(
          query: query,
          complianceId: complianceId,
        ),
        mockCall: () => _mock.acknowledgeCompliance(
          query: query,
          complianceId: complianceId,
        ),
      );

  @override
  Future<List<DirectorMetricInput>> getMetricInputs({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getMetricInputs(query: query),
        mockCall: () => _mock.getMetricInputs(query: query),
      );

  @override
  Future<DirectorMetricInput> saveMetricInput({
    required RepositoryQuery query,
    required DirectorMetricInputDraft draft,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.saveMetricInput(query: query, draft: draft),
        mockCall: () => _mock.saveMetricInput(query: query, draft: draft),
      );

  @override
  Future<DirectorBoardPack> exportReport({
    required RepositoryQuery query,
    required String reportId,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.exportReport(query: query, reportId: reportId),
        mockCall: () => _mock.exportReport(query: query, reportId: reportId),
      );
}

