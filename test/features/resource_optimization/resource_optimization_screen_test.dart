import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/resource_optimization/resource_optimization_models.dart';
import 'package:akshara_erp/features/resource_optimization/resource_optimization_repository.dart';
import 'package:akshara_erp/features/resource_optimization/resource_optimization_screen.dart';
import 'package:akshara_erp/features/resource_optimization/resource_optimization_providers.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements ResourceOptimizationRepository {
  final _applied = <String>{};
  final _dismissed = <String>{};

  @override
  Future<void> applyRecommendation({
    required RepositoryQuery query,
    required ResourceOptimizationDomain domain,
    required String recommendationId,
  }) async {
    _dismissed.remove(recommendationId);
    _applied.add(recommendationId);
  }

  @override
  Future<void> dismissRecommendation({
    required RepositoryQuery query,
    required ResourceOptimizationDomain domain,
    required String recommendationId,
  }) async {
    _applied.remove(recommendationId);
    _dismissed.add(recommendationId);
  }

  @override
  Future<List<OptimizationRecommendation>> listRecommendations({
    required RepositoryQuery query,
    required ResourceOptimizationDomain domain,
  }) async {
    return [
      OptimizationRecommendation(
        id: '${domain.name}_demo',
        domain: domain,
        title: '${domain.label} recommendation',
        summary: 'Summary',
        expectedImpact: 'Impact',
        confidence: 80,
        applied: _applied.contains('${domain.name}_demo'),
        dismissed: _dismissed.contains('${domain.name}_demo'),
      ),
    ];
  }
}

void main() {
  testWidgets('applies recommendation and shows success snackbar',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resourceOptimizationRepositoryProvider
              .overrideWithValue(_FakeRepository()),
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const ResourceOptimizationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(QaTestKeys.resourceOptimizationApplyButton('staffing_demo')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.resourceOptimizationAppliedSnackbar),
        findsOneWidget);
  });
}
