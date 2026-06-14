import '../../interfaces/platform_intelligence_repository.dart';
import '../../repository_query.dart';
import '../../../../features/control_center/intelligence/platform_intelligence_models.dart';
import 'mapper/platform_intelligence_mapper.dart';
import 'remote/platform_intelligence_remote_datasource.dart';

class ApiPlatformIntelligenceRepository
    implements PlatformIntelligenceRepository {
  ApiPlatformIntelligenceRepository({
    required PlatformIntelligenceRemoteDataSource remote,
    PlatformIntelligenceMapper mapper = const PlatformIntelligenceMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final PlatformIntelligenceRemoteDataSource _remote;
  final PlatformIntelligenceMapper _mapper;

  @override
  Future<PlatformIntelligenceDashboard> getPlatformIntelligenceDashboard({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto.data);
  }

  @override
  Future<OrganizationIntelligence> getOrganizationIntelligence({
    required RepositoryQuery query,
    required String orgId,
  }) async {
    final dto = await _remote.fetchOrganization(query: query, orgId: orgId);
    return _mapper.toOrganization(dto.data);
  }

  @override
  Future<SchoolComparisonIntelligence> compareSchools({
    required RepositoryQuery query,
    required List<String> schoolIds,
  }) async {
    final dto =
        await _remote.fetchComparison(query: query, schoolIds: schoolIds);
    return _mapper.toComparison(dto.data);
  }

  @override
  Future<RevenueIntelligence> getRevenueIntelligence({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchRevenue(query: query);
    return _mapper.toRevenue(dto.data);
  }

  @override
  Future<GrowthIntelligence> getGrowthIntelligence({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchGrowth(query: query);
    return _mapper.toGrowth(dto.data);
  }

  @override
  Future<PortfolioRiskIntelligence> getPortfolioRiskIntelligence({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchRisk(query: query);
    return _mapper.toRisk(dto.data);
  }
}
