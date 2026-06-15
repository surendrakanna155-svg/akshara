import 'package:akshara_erp/core/repositories/interfaces/platform_intelligence_repository.dart';
import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/repositories/mock/mock_platform_intelligence_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

const _query = RepositoryQuery.demo;

class _FakeAiProvider implements AiProvider {
  @override
  String get id => 'fake-ai';

  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    return const AiInferenceResponse(
      content:
          'rec_1|Stabilize collections|Resolve overdue campuses|Finance Lead|high',
      provider: 'fake-ai',
      fromCache: false,
      usedFallback: false,
    );
  }

  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {}
}

void main() {
  group('Platform intelligence contract', () {
    late MockPlatformIntelligenceRepository repository;

    setUp(() {
      repository = MockPlatformIntelligenceRepository(
        pipeline: AiInferencePipeline(
          provider: _FakeAiProvider(),
          cache: AiResponseCache(),
          telemetry: AiInferenceTelemetry(),
          rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
        ),
      );
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

    test('trust dashboard, recommendations, and executive summary resolve',
        () async {
      final trust = await repository.getTrustDashboard(
        query: _query,
        trustId: 'TRUST-001',
      );
      final recommendations = await repository.getCrossSchoolRecommendations(
        query: _query,
        schoolIds: const ['SCH-1001', 'SCH-1003'],
      );
      final summary = await repository.getExecutiveSummary(
        query: _query,
        trustId: 'TRUST-001',
      );
      expect(trust.kpis, isNotEmpty);
      expect(recommendations, isNotEmpty);
      expect(summary.headline, isNotEmpty);
    });
  });
}
