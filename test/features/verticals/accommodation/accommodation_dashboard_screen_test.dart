import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/repositories/mock/mock_accommodation_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/verticals/accommodation/accommodation_dashboard_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

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
  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockRepo = MockAccommodationRepository(
      pipeline: AiInferencePipeline(
        provider: _NoOpAiProvider(),
        cache: AiResponseCache(),
        telemetry: AiInferenceTelemetry(),
        rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accommodationRepositoryProvider.overrideWithValue(mockRepo),
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
          rbacServiceProvider.overrideWithValue(
            RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
          ),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const AccommodationDashboardScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('accommodation dashboard renders', (tester) async {
    await pumpDashboard(tester);
    expect(find.byKey(QaTestKeys.accommodationDashboardScreen), findsOneWidget);
  });
}
