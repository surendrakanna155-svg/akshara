import '../../interfaces/analytics_intelligence_repository.dart';
import '../../repository_query.dart';
import '../../../../features/intelligence/management/intelligence_models.dart';
import 'api_analytics_intelligence_repository.dart';

class HybridAnalyticsIntelligenceRepository implements AnalyticsIntelligenceRepository {
  HybridAnalyticsIntelligenceRepository({required ApiAnalyticsIntelligenceRepository api}) : _api = api;

  final ApiAnalyticsIntelligenceRepository _api;

  @override
  Future<IntelligenceDashboardMetrics> getDashboardMetrics({
    required RepositoryQuery query,
  }) =>
      _api.getDashboardMetrics(query: query);

  @override
  Future<IntelligenceTrendBundle> getTrends({
    required RepositoryQuery query,
  }) =>
      _api.getTrends(query: query);

  @override
  Future<IntelligenceRiskBundle> getRisks({
    required RepositoryQuery query,
  }) =>
      _api.getRisks(query: query);

  @override
  Future<IntelligenceSchoolHealthSummary> getSchoolHealth({
    required RepositoryQuery query,
  }) =>
      _api.getSchoolHealth(query: query);

  @override
  Future<List<IntelligenceRecommendation>> getRecommendations({
    required RepositoryQuery query,
  }) =>
      _api.getRecommendations(query: query);

  @override
  Future<IntelligencePrincipalSummary> getPrincipalSummary({
    required RepositoryQuery query,
  }) =>
      _api.getPrincipalSummary(query: query);

  @override
  Future<IntelligenceWeeklyBriefing> getWeeklyBriefing({
    required RepositoryQuery query,
  }) =>
      _api.getWeeklyBriefing(query: query);
}
