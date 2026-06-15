import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/repositories/api/platform_operations/api_platform_operations_repository.dart';
import 'package:akshara_erp/core/repositories/api/platform_operations/remote/platform_operations_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/platform_operations_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_platform_operations_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Platform operations repository contract', () {
    late MockPlatformOperationsRepository mockRepo;
    late ApiPlatformOperationsRepository apiRepo;

    setUp(() {
      mockRepo = MockPlatformOperationsRepository(
        pipeline: AiInferencePipeline(
          provider: _NoOpAiProvider(),
          cache: AiResponseCache(),
          telemetry: AiInferenceTelemetry(),
          rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
        ),
      );
      apiRepo = ApiPlatformOperationsRepository(
        remote: PlatformOperationsRemoteDataSource(Dio()),
      );
    });

    test('mock and api implement PlatformOperationsRepository', () {
      expect(mockRepo, isA<PlatformOperationsRepository>());
      expect(apiRepo, isA<PlatformOperationsRepository>());
    });

    test('getObservabilityDashboard returns audit KPIs', () async {
      final dashboard = await mockRepo.getObservabilityDashboard(
        query: RepositoryQuery.demo,
      );
      expect(dashboard.kpis, isNotEmpty);
      expect(dashboard.auditMetrics, isNotEmpty);
    });

    test('listActiveAlerts and acknowledgeAlert update status', () async {
      final alerts = await mockRepo.listActiveAlerts(
        query: RepositoryQuery.demo,
      );
      expect(alerts, isNotEmpty);
      final acknowledged = await mockRepo.acknowledgeAlert(
        query: RepositoryQuery.demo,
        alertId: alerts.first.id,
        note: 'contract test',
      );
      expect(acknowledged.status, 'acknowledged');
    });

    test('runTenantVerification returns report with findings', () async {
      final report = await mockRepo.runTenantVerification(
        query: RepositoryQuery.demo,
      );
      expect(report.status, 'completed');
      expect(report.findings, isNotEmpty);
    });

    test('getProductionReadinessReport includes categories', () async {
      final report = await mockRepo.getProductionReadinessReport(
        query: RepositoryQuery.demo,
      );
      expect(report.categories, isNotEmpty);
      expect(report.overallScore, greaterThan(0));
    });

    test('completeAccessReview marks review completed', () async {
      final reviews = await mockRepo.listAccessReviews(
        query: RepositoryQuery.demo,
      );
      final pending = reviews.firstWhere((item) => item.status == 'pending');
      final completed = await mockRepo.completeAccessReview(
        query: RepositoryQuery.demo,
        reviewId: pending.id,
      );
      expect(completed.status, 'completed');
    });
  });
}

class _NoOpAiProvider implements AiProvider {
  @override
  String get id => 'noop';

  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    return AiInferenceResponse(
      content: 'Mock AI recommendation for platform operations.',
      provider: id,
      fromCache: false,
      usedFallback: false,
      model: 'noop',
      latencyMs: 1,
    );
  }

  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {}
}
