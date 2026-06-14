import '../../../features/control_center/intelligence/platform_intelligence_models.dart';
import '../repository_query.dart';

abstract class PlatformIntelligenceRepository {
  Future<PlatformIntelligenceDashboard> getPlatformIntelligenceDashboard({
    required RepositoryQuery query,
  });

  Future<OrganizationIntelligence> getOrganizationIntelligence({
    required RepositoryQuery query,
    required String orgId,
  });

  Future<SchoolComparisonIntelligence> compareSchools({
    required RepositoryQuery query,
    required List<String> schoolIds,
  });

  Future<RevenueIntelligence> getRevenueIntelligence({
    required RepositoryQuery query,
  });

  Future<GrowthIntelligence> getGrowthIntelligence({
    required RepositoryQuery query,
  });

  Future<PortfolioRiskIntelligence> getPortfolioRiskIntelligence({
    required RepositoryQuery query,
  });
}
