import 'package:akshara_erp/core/repositories/mock/mock_analytics_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Analytics intelligence scoring', () {
    test('mock dashboard metrics stay within 0-100', () async {
      final repo = MockAnalyticsIntelligenceRepository();
      final metrics = await repo.getDashboardMetrics(query: RepositoryQuery.demo);
      expect(metrics.studentRiskScore, inInclusiveRange(0, 100));
      expect(metrics.timetableHealthScore, inInclusiveRange(0, 100));
      expect(metrics.communicationEngagementScore, inInclusiveRange(0, 100));
    });

    test('school health composition weights sum to 1', () async {
      final repo = MockAnalyticsIntelligenceRepository();
      final health = await repo.getSchoolHealth(query: RepositoryQuery.demo);
      final weightSum = health.composition.fold<double>(0, (sum, item) => sum + item.weight);
      expect(weightSum, closeTo(1, 0.001));
    });

    test('trend series include school health trajectory', () async {
      final repo = MockAnalyticsIntelligenceRepository();
      final trends = await repo.getTrends(query: RepositoryQuery.demo);
      expect(trends.series['schoolHealth'], isNotNull);
      expect(trends.series['schoolHealth']!.length, 5);
    });

    test('recommendations remain advisory only in mock bundle', () async {
      final repo = MockAnalyticsIntelligenceRepository();
      final recommendations = await repo.getRecommendations(query: RepositoryQuery.demo);
      expect(recommendations, isNotEmpty);
      expect(
        recommendations.every((item) => item.detail.toLowerCase().contains('read-only')),
        isTrue,
      );
    });
  });
}
