import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/repositories/api/salon/api_salon_repository.dart';
import 'package:akshara_erp/core/repositories/api/salon/remote/salon_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/salon_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_salon_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoOpAiProvider implements AiProvider {
  @override
  String get id => 'noop';
  @override
  Future<AiInferenceResponse> complete(AiInferenceRequest request) async {
    return const AiInferenceResponse(
      content: 'ok',
      provider: 'noop',
      fromCache: false,
      usedFallback: false,
    );
  }
  @override
  Stream<AiInferenceStreamChunk> stream(AiInferenceRequest request) async* {
    yield const AiInferenceStreamChunk(delta: '', done: true);
  }
}

void main() {
  group('salon repository contract', () {
    late MockSalonRepository mockRepo;
    late ApiSalonRepository apiRepo;

    setUp(() {
      mockRepo = MockSalonRepository(
        pipeline: AiInferencePipeline(
          provider: _NoOpAiProvider(),
          cache: AiResponseCache(),
          telemetry: AiInferenceTelemetry(),
          rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
        ),
      );
      apiRepo = ApiSalonRepository(
        remote: SalonRemoteDataSource(Dio()),
      );
    });

    test('mock and api implement SalonRepository', () {
      expect(mockRepo, isA<SalonRepository>());
      expect(apiRepo, isA<SalonRepository>());
    });

    test('getDashboard returns data', () async {
      final dashboard = await mockRepo.getDashboard(query: RepositoryQuery.demo);
      expect(dashboard.summary, isNotEmpty);
    });
  });
}
