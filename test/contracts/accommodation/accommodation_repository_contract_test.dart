import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/repositories/api/accommodation/api_accommodation_repository.dart';
import 'package:akshara_erp/core/repositories/api/accommodation/remote/accommodation_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/accommodation_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_accommodation_repository.dart';
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
  group('accommodation repository contract', () {
    late MockAccommodationRepository mockRepo;
    late ApiAccommodationRepository apiRepo;

    setUp(() {
      mockRepo = MockAccommodationRepository(
        pipeline: AiInferencePipeline(
          provider: _NoOpAiProvider(),
          cache: AiResponseCache(),
          telemetry: AiInferenceTelemetry(),
          rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
        ),
      );
      apiRepo = ApiAccommodationRepository(
        remote: AccommodationRemoteDataSource(Dio()),
      );
    });

    test('mock and api implement AccommodationRepository', () {
      expect(mockRepo, isA<AccommodationRepository>());
      expect(apiRepo, isA<AccommodationRepository>());
    });

    test('getDashboard returns data', () async {
      final dashboard = await mockRepo.getDashboard(query: RepositoryQuery.demo);
      expect(dashboard.summary, isNotEmpty);
    });
  });
}
