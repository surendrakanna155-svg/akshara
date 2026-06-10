import 'package:akshara_erp/core/repositories/api/analytics/api_analytics_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/api/analytics/remote/analytics_intelligence_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/analytics/remote/analytics_intelligence_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_analytics_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/analytics/analytics_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';

const kQuery = RepositoryQuery.demo;
final _fixtures = AnalyticsIntelligenceFixtureBuilder();

void main() {
  group('Analytics intelligence API integration', () {
    late MockAnalyticsIntelligenceRepository mockRepo;
    late ApiAnalyticsIntelligenceRepository apiRepo;

    setUp(() async {
      mockRepo = MockAnalyticsIntelligenceRepository();
      final dashboard = await mockRepo.getDashboardMetrics(query: kQuery);
      final health = await mockRepo.getSchoolHealth(query: kQuery);
      final risks = await mockRepo.getRisks(query: kQuery);

      final dio = createFakeDio((options) {
        if (options.path == AnalyticsIntelligenceApiPaths.dashboard) {
          return _fixtures.dashboardEnvelope(dashboard);
        }
        if (options.path == AnalyticsIntelligenceApiPaths.health) {
          return _fixtures.healthEnvelope(health);
        }
        if (options.path == AnalyticsIntelligenceApiPaths.risks) {
          return _fixtures.risksEnvelope(risks);
        }
        throw UnsupportedError('Unexpected path: ${options.path}');
      });

      apiRepo = ApiAnalyticsIntelligenceRepository(
        remote: AnalyticsIntelligenceRemoteDataSource(dio),
      );
    });

    test('dashboard API parity with mock', () async {
      final mockData = await mockRepo.getDashboardMetrics(query: kQuery);
      final apiData = await apiRepo.getDashboardMetrics(query: kQuery);
      expect(apiData.studentRiskScore, mockData.studentRiskScore);
      expect(apiData.communicationEngagementScore, mockData.communicationEngagementScore);
    });

    test('health API parity with mock', () async {
      final mockData = await mockRepo.getSchoolHealth(query: kQuery);
      final apiData = await apiRepo.getSchoolHealth(query: kQuery);
      expect(apiData.schoolHealthScore, mockData.schoolHealthScore);
      expect(apiData.composition.length, mockData.composition.length);
    });

    test('risks API parity with mock', () async {
      final mockData = await mockRepo.getRisks(query: kQuery);
      final apiData = await apiRepo.getRisks(query: kQuery);
      expect(apiData.items.length, mockData.items.length);
      expect(apiData.items.first.score, mockData.items.first.score);
    });
  });
}
