import '../../interfaces/platform_intelligence_repository.dart';
import '../../repository_query.dart';
import '../../../ai/ai_inference_models.dart';
import '../../../ai/ai_inference_pipeline.dart';
import '../../../../features/control_center/intelligence/platform_intelligence_models.dart';
import 'mapper/platform_intelligence_mapper.dart';
import 'remote/platform_intelligence_remote_datasource.dart';

class ApiPlatformIntelligenceRepository
    implements PlatformIntelligenceRepository {
  ApiPlatformIntelligenceRepository({
    required PlatformIntelligenceRemoteDataSource remote,
    AiInferencePipeline? pipeline,
    PlatformIntelligenceMapper mapper = const PlatformIntelligenceMapper(),
  })  : _remote = remote,
        _pipeline = pipeline,
        _mapper = mapper;

  final PlatformIntelligenceRemoteDataSource _remote;
  final AiInferencePipeline? _pipeline;
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

  @override
  Future<TrustDashboardIntelligence> getTrustDashboard({
    required RepositoryQuery query,
    required String trustId,
  }) async {
    final dto =
        await _remote.fetchTrustDashboard(query: query, trustId: trustId);
    return _mapper.toTrustDashboard(dto.data);
  }

  @override
  Future<List<CrossSchoolRecommendation>> getCrossSchoolRecommendations({
    required RepositoryQuery query,
    required List<String> schoolIds,
  }) async {
    final fallback = _fallbackRecommendations(schoolIds);
    if (_pipeline == null) {
      return fallback;
    }

    final response = await _pipeline.complete(
      AiInferenceRequest(
        prompt: _recommendationPrompt(query: query, schoolIds: schoolIds),
        taskType: aiTaskTypeName(AiInferenceTaskType.intelligenceCompute),
        systemPrompt:
            'Return cross-school trust recommendations as id|title|detail|owner|priority.',
        context: {
          'module': 'organization_intelligence',
          'organizationId': query.organizationId,
          'tenantId': query.tenantId,
          'schoolIds': schoolIds.join(','),
        },
      ),
    );
    final parsed = _parseRecommendations(response.content);
    return parsed.isEmpty ? fallback : parsed;
  }

  @override
  Future<ExecutiveSummaryIntelligence> getExecutiveSummary({
    required RepositoryQuery query,
    required String trustId,
  }) async {
    final dto =
        await _remote.fetchExecutiveSummary(query: query, trustId: trustId);
    return _mapper.toExecutiveSummary(dto.data);
  }

  String _recommendationPrompt({
    required RepositoryQuery query,
    required List<String> schoolIds,
  }) {
    return 'Generate 3 cross-school recommendations for trust operations. '
        'Return one line each as id|title|detail|owner|priority. '
        'Tenant ${query.tenantId}, organization ${query.organizationId}, '
        'schools ${schoolIds.join(",")}.';
  }

  List<CrossSchoolRecommendation> _parseRecommendations(String content) {
    final rows = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final recommendations = <CrossSchoolRecommendation>[];
    for (final row in rows) {
      final parts = row.split('|');
      if (parts.length < 5) continue;
      recommendations.add(
        CrossSchoolRecommendation(
          id: _normalizedId(parts[0]),
          title: parts[1].trim(),
          detail: parts[2].trim(),
          owner: parts[3].trim(),
          priority: parts[4].trim(),
        ),
      );
    }
    return recommendations;
  }

  List<CrossSchoolRecommendation> _fallbackRecommendations(
      List<String> schoolIds) {
    final selected = schoolIds.isEmpty ? 'portfolio' : schoolIds.join(', ');
    return [
      CrossSchoolRecommendation(
        id: 'collections_recovery_wave',
        title: 'Launch collections recovery wave',
        detail:
            'Target overdue campuses in $selected with parent reminder automation and weekly closures.',
        owner: 'Finance Lead',
        priority: 'high',
      ),
      const CrossSchoolRecommendation(
        id: 'teacher_capacity_rebalance',
        title: 'Rebalance high-load grade clusters',
        detail:
            'Shift two overloaded grade clusters to shared teacher pools before new term.',
        owner: 'Academic Coordinator',
        priority: 'high',
      ),
      const CrossSchoolRecommendation(
        id: 'premium_conversion_cohort',
        title: 'Create premium conversion cohort',
        detail:
            'Upsell high-usage schools using analytics adoption and outcome proof packs.',
        owner: 'Growth Manager',
        priority: 'medium',
      ),
    ];
  }

  String _normalizedId(String raw) {
    final value = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return value.isEmpty ? 'recommendation' : value;
  }
}
