import '../../../features/intelligence/management/intelligence_models.dart';
import '../repository_query.dart';

abstract class AnalyticsIntelligenceRepository {
  Future<IntelligenceDashboardMetrics> getDashboardMetrics({
    required RepositoryQuery query,
  });

  Future<IntelligenceTrendBundle> getTrends({
    required RepositoryQuery query,
  });

  Future<IntelligenceRiskBundle> getRisks({
    required RepositoryQuery query,
  });

  Future<IntelligenceSchoolHealthSummary> getSchoolHealth({
    required RepositoryQuery query,
  });

  Future<List<IntelligenceRecommendation>> getRecommendations({
    required RepositoryQuery query,
  });

  Future<IntelligencePrincipalSummary> getPrincipalSummary({
    required RepositoryQuery query,
  });

  Future<IntelligenceWeeklyBriefing> getWeeklyBriefing({
    required RepositoryQuery query,
  });
}
