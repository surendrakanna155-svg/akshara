import 'package:akshara_erp/core/repositories/interfaces/platform_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_platform_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery.demo;

void main() {
  group('Platform intelligence contract', () {
    late MockPlatformIntelligenceRepository repository;

    setUp(() {
      repository = MockPlatformIntelligenceRepository();
    });

    test('implements repository contract', () {
      expect(repository, isA<PlatformIntelligenceRepository>());
    });

    test('dashboard contains platform owner + organization KPIs', () async {
      final dashboard =
          await repository.getPlatformIntelligenceDashboard(query: _query);
      expect(dashboard.ownerKpis, isNotEmpty);
      expect(dashboard.organizationKpis, isNotEmpty);
      expect(dashboard.topInsights, isNotEmpty);
    });

    test('organization response is scoped by orgId', () async {
      final data = await repository.getOrganizationIntelligence(
        query: _query,
        orgId: 'ORG-TRUST-01',
      );
      expect(data.organizationId, 'ORG-TRUST-01');
      expect(data.healthScore, greaterThan(0));
    });

    test('school comparison filters when schoolIds supplied', () async {
      final comparison = await repository.compareSchools(
        query: _query,
        schoolIds: const ['SCH-1001', 'SCH-1003'],
      );
      expect(comparison.rows, hasLength(2));
    });

    test('revenue, growth and risk intelligence return complete sections',
        () async {
      final revenue = await repository.getRevenueIntelligence(query: _query);
      final growth = await repository.getGrowthIntelligence(query: _query);
      final risk = await repository.getPortfolioRiskIntelligence(query: _query);

      expect(revenue.kpis, isNotEmpty);
      expect(growth.pipeline, isNotEmpty);
      expect(risk.risks, isNotEmpty);
    });
  });
}
