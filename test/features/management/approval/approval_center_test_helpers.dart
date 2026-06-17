import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/management/approval/principal_approval_center_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/auth_test_overrides.dart';
import '../../../helpers/provider_test_overrides.dart';
import '../../../test_helpers.dart';

Future<void> pumpApprovalCenter(
  WidgetTester tester, {
  Size viewport = const Size(1440, 900),
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await initProviderTestPrefs();

  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides([
        environmentProvider.overrideWith(
          (ref) => Environment.development.copyWith(enableQaLogin: true),
        ),
        authStateOverride(erpWidgetTestStaffAuth()),
        ...extraOverrides,
      ]),
      child: MaterialApp.router(
        theme: AksharaAppTheme.light(),
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const PrincipalApprovalCenterScreen(),
            ),
          ],
        ),
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

AuthState teacherAuthWithoutManagementApprove() {
  return AuthState(
    status: AuthStatus.authenticated,
    phoneNumber: '8888888888',
    displayName: 'Test Teacher',
    role: UserRole.staff,
    claims: AuthClaims.demoForRole(erpRole: ErpRole.teacher),
  );
}

Finder approvalApproveButtons() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('approval_approve_'),
    );

Finder approvalRejectButtons() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('approval_reject_'),
    );
