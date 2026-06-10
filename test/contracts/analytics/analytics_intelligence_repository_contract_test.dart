import 'package:akshara_erp/core/repositories/api/analytics/api_analytics_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/api/analytics/dto/analytics_intelligence_dto.dart';
import 'package:akshara_erp/core/repositories/api/analytics/mapper/analytics_intelligence_mapper.dart';
import 'package:akshara_erp/core/repositories/api/analytics/remote/analytics_intelligence_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/analytics_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_analytics_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'analytics_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
final _fixtures = AnalyticsIntelligenceFixtureBuilder();
const _mapper = AnalyticsIntelligenceMapper();

void main() {
  group('Analytics intelligence repository contract', () {
    late MockAnalyticsIntelligenceRepository mockRepo;
    late ApiAnalyticsIntelligenceRepository apiRepo;

    setUp(() {
      mockRepo = MockAnalyticsIntelligenceRepository();
      apiRepo = ApiAnalyticsIntelligenceRepository(
        remote: AnalyticsIntelligenceRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement AnalyticsIntelligenceRepository', () {
      expect(mockRepo, isA<AnalyticsIntelligenceRepository>());
      expect(apiRepo, isA<AnalyticsIntelligenceRepository>());
    });

    test('dashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboardMetrics(query: kQuery);
      final mapped = _mapper.toDashboard(
        IntelligenceDashboardMetricsDto.fromJson(
          _fixtures.dashboardEnvelope(mockData)['data'] as Map<String, dynamic>,
        ),
      );
      expect(mapped.studentRiskScore, mockData.studentRiskScore);
      expect(mapped.timetableHealthScore, mockData.timetableHealthScore);
    });

    test('health DTO mapping includes composition weights', () async {
      final mockData = await mockRepo.getSchoolHealth(query: kQuery);
      final mapped = _mapper.toHealth(
        IntelligenceSchoolHealthSummaryDto.fromJson(
          _fixtures.healthEnvelope(mockData)['data'] as Map<String, dynamic>,
        ),
      );
      expect(mapped.schoolHealthScore, mockData.schoolHealthScore);
      expect(mapped.composition.length, 4);
      expect(
        mapped.composition.fold<double>(0, (sum, item) => sum + item.weight),
        closeTo(1, 0.001),
      );
    });

    test('risk DTO mapping preserves levels', () async {
      final mockData = await mockRepo.getRisks(query: kQuery);
      final mapped = _mapper.toRisk(
        IntelligenceRiskMetricDto.fromJson(
          (_fixtures.risksEnvelope(mockData)['data'] as Map<String, dynamic>)['items']
              .first as Map<String, dynamic>,
        ),
      );
      expect(mapped.id, mockData.items.first.id);
      expect(mapped.level, mockData.items.first.level);
    });
  });
}
