import 'package:akshara_erp/core/repositories/api/platform_intelligence/api_platform_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/api/platform_intelligence/remote/platform_intelligence_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/platform_intelligence/remote/platform_intelligence_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/control_center/intelligence/platform_intelligence_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const _query = RepositoryQuery.demo;

void main() {
  group('Platform intelligence integration', () {
    Map<String, dynamic> responseFor(String path) {
      return switch (path) {
        PlatformIntelligenceApiPaths.dashboard => {
            'data': {
              'ownerKpis': [
                {
                  'id': 'portfolio_revenue',
                  'label': 'Portfolio Revenue',
                  'value': 'INR 786.4L'
                },
              ],
              'organizationKpis': [
                {'id': 'org_count', 'label': 'Organizations', 'value': '6'},
              ],
              'topInsights': [
                {
                  'title': 'Collections lagging in two campuses',
                  'detail': 'Action required',
                  'priority': 'high'
                },
              ],
            },
          },
        PlatformIntelligenceApiPaths.organization => {
            'data': {
              'organizationId': 'ORG-001',
              'organizationName': 'Akshara Education Trust',
              'schoolCount': 11,
              'activeStudentCount': 28940,
              'revenueLakhs': 214.6,
              'collectionEfficiencyPercent': 97,
              'healthScore': 89,
              'recommendations': ['Expand premium analytics'],
            },
          },
        PlatformIntelligenceApiPaths.compare => {
            'data': {
              'rows': [
                {
                  'schoolId': 'SCH-1001',
                  'schoolName': 'Akshara International Hyderabad',
                  'studentCount': 2840,
                  'revenueLakhs': 52.4,
                  'growthPercent': 13,
                  'riskScore': 14,
                },
              ],
              'benchmarks': [
                {
                  'title': 'Best growth momentum',
                  'detail': 'Sunrise leads',
                  'priority': 'high'
                },
              ],
            },
          },
        PlatformIntelligenceApiPaths.revenue => {
            'data': {
              'kpis': [
                {'id': 'mrr', 'label': 'MRR', 'value': 'INR 65.8L'},
              ],
              'revenueTrend': [
                {'label': 'Jun', 'value': 65.8, 'target': 64.0},
              ],
              'organizationBreakdown': [
                {
                  'id': 'org_akshara',
                  'label': 'Akshara Trust',
                  'value': 'INR 22.4L'
                },
              ],
            },
          },
        PlatformIntelligenceApiPaths.growth => {
            'data': {
              'kpis': [
                {
                  'id': 'pipeline_value',
                  'label': 'Pipeline Value',
                  'value': 'INR 148L'
                },
              ],
              'pipeline': [
                {
                  'name': 'East Region Expansion',
                  'stage': 'Negotiation',
                  'expectedRevenueLakhs': 34.0,
                  'timeline': 'Q3 FY27',
                },
              ],
              'expansionSignals': [
                {
                  'title': 'Admissions-led expansion',
                  'detail': '4 schools crossed threshold',
                  'priority': 'medium'
                },
              ],
            },
          },
        PlatformIntelligenceApiPaths.risk => {
            'data': {
              'kpis': [
                {
                  'id': 'avg_risk',
                  'label': 'Average Portfolio Risk',
                  'value': '18'
                },
              ],
              'riskTrend': [
                {'label': 'Jun', 'value': 18},
              ],
              'risks': [
                {
                  'schoolId': 'SCH-1004',
                  'schoolName': 'Heritage Convent Pune',
                  'riskType': 'Collection default',
                  'riskScore': 36,
                  'mitigation': 'Assign CS + finance audit',
                },
              ],
            },
          },
        PlatformIntelligenceApiPaths.trustDashboard => {
            'data': {
              'trustName': 'Akshara Trust Network',
              'kpis': [
                {'id': 'trust_health', 'label': 'Trust Health', 'value': '87'},
              ],
              'trend': [
                {'label': 'Jun', 'value': 87},
              ],
              'riskHighlights': [
                {
                  'title': 'Collections risk concentrated',
                  'detail': 'Action required',
                  'priority': 'high'
                },
              ],
            },
          },
        PlatformIntelligenceApiPaths.executiveSummary => {
            'data': {
              'headline': 'Trust trajectory remains positive.',
              'summary': 'Strong growth with targeted interventions.',
              'priorityActions': [
                {
                  'title': 'Execute fee recovery sprint',
                  'detail': '30-day execution window',
                  'priority': 'high'
                },
              ],
            },
          },
        _ => const {'data': {}},
      };
    }

    test('api repository maps all platform intelligence endpoints', () async {
      final repository = ApiPlatformIntelligenceRepository(
        remote: PlatformIntelligenceRemoteDataSource(
          createFakeDio((options) => responseFor(options.path)),
        ),
      );

      final dashboard =
          await repository.getPlatformIntelligenceDashboard(query: _query);
      final organization = await repository.getOrganizationIntelligence(
        query: _query,
        orgId: 'ORG-001',
      );
      final comparison = await repository.compareSchools(
        query: _query,
        schoolIds: const ['SCH-1001'],
      );
      final revenue = await repository.getRevenueIntelligence(query: _query);
      final growth = await repository.getGrowthIntelligence(query: _query);
      final risk = await repository.getPortfolioRiskIntelligence(query: _query);
      final trust = await repository.getTrustDashboard(
        query: _query,
        trustId: 'TRUST-001',
      );
      final summary = await repository.getExecutiveSummary(
        query: _query,
        trustId: 'TRUST-001',
      );
      final recommendations = await repository.getCrossSchoolRecommendations(
        query: _query,
        schoolIds: const ['SCH-1001'],
      );

      expect(dashboard.ownerKpis, isNotEmpty);
      expect(organization.organizationName, contains('Akshara'));
      expect(comparison.rows.first.schoolId, 'SCH-1001');
      expect(revenue.revenueTrend.first.label, 'Jun');
      expect(growth.pipeline.first.name, 'East Region Expansion');
      expect(risk.risks.first.riskScore, 36);
      expect(trust.trustName, contains('Akshara'));
      expect(summary.priorityActions, isNotEmpty);
      expect(recommendations, isNotEmpty);
    });

    test('provider chain loads dashboard in api mode', () async {
      await initProviderTestPrefs();
      final container = createProviderTestContainer(
        apiPlatformIntelligenceDio:
            createFakeDio((options) => responseFor(options.path)),
        platformIntelligenceApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data =
          await container.read(platformIntelligenceDashboardProvider.future);
      expect(data.ownerKpis, isNotEmpty);
    });
  });
}
