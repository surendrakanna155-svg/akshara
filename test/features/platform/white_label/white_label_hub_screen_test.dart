import 'package:akshara_erp/core/repositories/mock/mock_white_label_platform_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
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

final _whiteLabelOperator = UserPermissions.fromClaims(
  role: ErpRole.superAdmin,
  explicitPermissions: const [
    Permission.viewWhiteLabelPlatform,
    Permission.manageWhiteLabelPlatform,
  ],
);

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
          // SA-1 (MJ-L5): superAdmin no longer holds white-label perms in the
          // matrix (unseeded server-side); grant them explicitly so this hub
          // smoke test still exercises the screen.
          userPermissionsProvider.overrideWithValue(_whiteLabelOperator),
          rbacServiceProvider.overrideWithValue(
            RbacService(_whiteLabelOperator),
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
