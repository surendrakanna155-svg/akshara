import 'package:akshara_erp/core/repositories/mock/mock_evolution_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/dynamic_widgets/dynamic_widget_registry_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void main() {
  Future<void> pumpRegistry(WidgetTester tester) async {
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
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
          rbacServiceProvider.overrideWithValue(
            RbacService(UserPermissions.forRole(ErpRole.superAdmin)),
          ),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const DynamicWidgetRegistryScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('renders widget catalog and data sources', (tester) async {
    await pumpRegistry(tester);

    expect(find.byKey(QaTestKeys.dynamicWidgetRegistryScreen), findsOneWidget);
    expect(find.text('School Health'), findsOneWidget);
    expect(find.text('School health score'), findsOneWidget);
    expect(find.byKey(QaTestKeys.dynamicWidgetCatalogItem('school_health')),
        findsOneWidget);
    expect(
      find.byKey(QaTestKeys.dynamicWidgetDataSourceItem('operations.school_health')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(QaTestKeys.dynamicWidgetLayoutVersion('principal')),
      120,
    );
    expect(
      find.byKey(QaTestKeys.dynamicWidgetLayoutVersion('principal')),
      findsOneWidget,
    );
  });
}
