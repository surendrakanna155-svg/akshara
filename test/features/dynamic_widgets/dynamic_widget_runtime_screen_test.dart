import 'package:akshara_erp/core/repositories/mock/mock_evolution_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/dynamic_widgets/dynamic_widget_providers.dart';
import 'package:akshara_erp/features/dynamic_widgets/dynamic_widget_runtime_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void main() {
  Future<void> pumpRuntime(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          evolutionRepositoryProvider.overrideWithValue(MockEvolutionRepository()),
          repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
          dynamicWidgetRoleProvider.overrideWith((ref) => ErpRole.principal.name),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
          rbacServiceProvider.overrideWithValue(
            RbacService(UserPermissions.forRole(ErpRole.principal)),
          ),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const DynamicWidgetRuntimeScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('renders RBAC-filtered principal widgets with live data', (tester) async {
    await pumpRuntime(tester);

    expect(find.byKey(QaTestKeys.dynamicWidgetRuntimeScreen), findsOneWidget);
    expect(find.byKey(QaTestKeys.dynamicWidgetRuntimeTile('school_health')),
        findsOneWidget);
    expect(find.byKey(QaTestKeys.dynamicWidgetRuntimeTile('fee_collection')),
        findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('₹1.2L'), findsOneWidget);
  });

  test('live data provider does not request RBAC-hidden widgets', () async {
    // Principal layout = school_health, student_risk, fee_collection,
    // attendance_risk. Grant everything EXCEPT viewFinance so fee_collection
    // is hidden and must never be requested.
    final restricted = UserPermissions(
      role: ErpRole.principal,
      permissionSet: PermissionSet.from(
        Permission.values.where((p) => p != Permission.viewFinance),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        evolutionRepositoryProvider.overrideWithValue(MockEvolutionRepository()),
        repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
        rbacServiceProvider.overrideWithValue(RbacService(restricted)),
      ],
    );
    addTearDown(container.dispose);

    final data = await container
        .read(dynamicWidgetLiveDataProvider(ErpRole.principal.name).future);

    expect(data.containsKey('fee_collection'), isFalse,
        reason: 'hidden widget data must not cross the wire');
    expect(data.containsKey('school_health'), isTrue);
    expect(data.containsKey('student_risk'), isTrue);
    expect(data.containsKey('attendance_risk'), isTrue);
  });
}
