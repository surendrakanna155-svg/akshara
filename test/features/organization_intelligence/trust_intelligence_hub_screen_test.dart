import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/organization_intelligence/trust_intelligence_hub_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides([
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ]),
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const TrustIntelligenceHubScreen(),
        ),
      ),
    );
    await settleRiverpodFutures(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('renders trust intelligence tabs', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Trust'), findsOneWidget);
    expect(find.text('Comparison'), findsOneWidget);
    expect(find.text('Revenue'), findsOneWidget);
    expect(find.text('Growth'), findsOneWidget);
    expect(find.text('Risk'), findsOneWidget);
    expect(find.text('Recommendations'), findsOneWidget);
    expect(find.text('Executive Summary'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
