import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/repositories/api/restaurant/api_restaurant_repository.dart';
import 'package:akshara_erp/core/repositories/api/restaurant/remote/restaurant_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/restaurant_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_restaurant_repository.dart';
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
  group('restaurant repository contract', () {
    late MockRestaurantRepository mockRepo;
    late ApiRestaurantRepository apiRepo;

    setUp(() {
      mockRepo = MockRestaurantRepository(
        pipeline: AiInferencePipeline(
          provider: _NoOpAiProvider(),
          cache: AiResponseCache(),
          telemetry: AiInferenceTelemetry(),
          rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
        ),
      );
      apiRepo = ApiRestaurantRepository(
        remote: RestaurantRemoteDataSource(Dio()),
      );
    });

    test('mock and api implement RestaurantRepository', () {
      expect(mockRepo, isA<RestaurantRepository>());
      expect(apiRepo, isA<RestaurantRepository>());
    });

    test('getDashboard returns data', () async {
      final dashboard = await mockRepo.getDashboard(query: RepositoryQuery.demo);
      expect(dashboard.summary, isNotEmpty);
    });
  });
}
