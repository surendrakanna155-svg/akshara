import '../../interfaces/analytics_intelligence_repository.dart';
import '../../repository_query.dart';
import '../../../../features/intelligence/management/intelligence_models.dart';
import 'dto/analytics_intelligence_dto.dart';
import 'mapper/analytics_intelligence_mapper.dart';
import 'remote/analytics_intelligence_remote_datasource.dart';

class ApiAnalyticsIntelligenceRepository implements AnalyticsIntelligenceRepository {
  ApiAnalyticsIntelligenceRepository({
    required AnalyticsIntelligenceRemoteDataSource remote,
    AnalyticsIntelligenceMapper mapper = const AnalyticsIntelligenceMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final AnalyticsIntelligenceRemoteDataSource _remote;
  final AnalyticsIntelligenceMapper _mapper;

  @override
  Future<IntelligenceDashboardMetrics> getDashboardMetrics({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<IntelligenceTrendBundle> getTrends({
    required RepositoryQuery query,
  }) async {
    final series = await _remote.fetchTrends(query: query);
    return IntelligenceTrendBundle(
      series: series.map(
        (key, value) => MapEntry(key, value.map(_mapper.toTrendPoint).toList()),
      ),
    );
  }

  @override
  Future<IntelligenceRiskBundle> getRisks({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchRisks(query: query);
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((item) => _mapper.toRisk(IntelligenceRiskMetricDto.fromJson(item as Map<String, dynamic>)))
        .toList();
    final anomalies = (data['anomalies'] as List<dynamic>? ?? const [])
        .map((item) => _mapper.toAnomaly(IntelligenceAnomalyDto.fromJson(item as Map<String, dynamic>)))
        .toList();
    return IntelligenceRiskBundle(items: items, anomalies: anomalies);
  }

  @override
  Future<IntelligenceSchoolHealthSummary> getSchoolHealth({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchHealth(query: query);
    return _mapper.toHealth(dto);
  }

  @override
  Future<List<IntelligenceRecommendation>> getRecommendations({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.fetchRecommendations(query: query);
    return items.map(_mapper.toRecommendation).toList();
  }

  @override
  Future<IntelligencePrincipalSummary> getPrincipalSummary({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchPrincipalSummary(query: query);
    return _mapper.toPrincipalSummary(dto);
  }

  @override
  Future<IntelligenceWeeklyBriefing> getWeeklyBriefing({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchWeeklyBriefing(query: query);
    return _mapper.toWeeklyBriefing(dto);
  }
}
