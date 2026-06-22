import 'package:akshara_erp/core/repositories/mock/mock_white_label_platform_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/platform/white_label/white_label_hub_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

void main() {
  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          whiteLabelPlatformRepositoryProvider
              .overrideWithValue(MockWhiteLabelPlatformRepository()),
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
          home: const WhiteLabelHubScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('white label hub renders', (tester) async {
    await pumpHub(tester);
    expect(find.byKey(QaTestKeys.whiteLabelHubScreen), findsOneWidget);
  });
}
