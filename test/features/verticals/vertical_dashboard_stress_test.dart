import 'package:akshara_erp/core/ai/ai_inference_models.dart';
import 'package:akshara_erp/core/ai/ai_inference_pipeline.dart';
import 'package:akshara_erp/core/ai/ai_inference_telemetry.dart';
import 'package:akshara_erp/core/ai/ai_provider.dart';
import 'package:akshara_erp/core/ai/ai_response_cache.dart';
import 'package:akshara_erp/core/repositories/mock/mock_accommodation_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_healthcare_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_restaurant_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_salon_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/verticals/accommodation/accommodation_dashboard_screen.dart';
import 'package:akshara_erp/features/verticals/healthcare/healthcare_dashboard_screen.dart';
import 'package:akshara_erp/features/verticals/restaurant/restaurant_dashboard_screen.dart';
import 'package:akshara_erp/features/verticals/salon/salon_dashboard_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/stress_fixtures.dart';
import '../../test_helpers.dart';

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

AiInferencePipeline _pipeline() => AiInferencePipeline(
      provider: _NoOpAiProvider(),
      cache: AiResponseCache(),
      telemetry: AiInferenceTelemetry(),
      rbac: RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
    );

List<Override> _verticalOverrides() {
  final pipeline = _pipeline();
  return [
    salonRepositoryProvider.overrideWithValue(
      MockSalonRepository(pipeline: pipeline),
    ),
    healthcareRepositoryProvider.overrideWithValue(
      MockHealthcareRepository(pipeline: pipeline),
    ),
    restaurantRepositoryProvider.overrideWithValue(
      MockRestaurantRepository(pipeline: pipeline),
    ),
    accommodationRepositoryProvider.overrideWithValue(
      MockAccommodationRepository(pipeline: pipeline),
    ),
    repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
    userPermissionsProvider.overrideWithValue(
      UserPermissions.forRole(ErpRole.superAdmin),
    ),
    rbacServiceProvider.overrideWithValue(
      RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
    ),
  ];
}

Future<void> pumpVerticalScreen(
  WidgetTester tester, {
  required Widget screen,
  required Size viewport,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _verticalOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  const verticalScreens = <Widget>[
    SalonDashboardScreen(),
    HealthcareDashboardScreen(),
    RestaurantDashboardScreen(),
    AccommodationDashboardScreen(),
  ];

  group('vertical dashboards — responsive stress', () {
    for (final viewport in StressFixtures.stressViewports) {
      for (final screen in verticalScreens) {
        testWidgets(
          '${screen.runtimeType} ${viewport.label} no overflow',
          (tester) async {
            await pumpVerticalScreen(
              tester,
              screen: screen,
              viewport: viewport.size,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('vertical dashboards — text scale stress', () {
    for (final scale in StressFixtures.textScales) {
      testWidgets('SalonDashboardScreen textScale $scale', (tester) async {
        await pumpVerticalScreen(
          tester,
          screen: const SalonDashboardScreen(),
          viewport: const Size(1440, 900),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
