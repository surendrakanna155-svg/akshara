import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/admin/admin_navigation_rail.dart';
import 'package:akshara_erp/features/admin/admin_shell.dart';
import 'package:akshara_erp/features/admin/models/admin_nav_models.dart';
import 'package:akshara_erp/features/admin/screens/admin_module_placeholder_screen.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/auth_test_overrides.dart';

void useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

GoRouter _adminTestRouter({String initialLocation = RouteNames.admin}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.admin,
            builder: (_, __) =>
                const AdminModulePlaceholderScreen(module: AdminModule.admin),
          ),
          GoRoute(
            path: RouteNames.admissions,
            builder: (_, __) => const AdminModulePlaceholderScreen(
              module: AdminModule.admissions,
            ),
          ),
        ],
      ),
    ],
  );
}

Future<void> pumpAdminShell(
  WidgetTester tester, {
  required Size viewport,
  String initialRoute = RouteNames.admin,
}) async {
  useViewport(tester, viewport);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateOverride(
          AuthState(
            status: AuthStatus.authenticated,
            phoneNumber: '9876543210',
            displayName: 'ERP Staff',
            role: UserRole.staff,
            claims: AuthClaims.demoForRole(erpRole: ErpRole.superAdmin),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: AksharaAppTheme.light(),
        routerConfig: _adminTestRouter(initialLocation: initialRoute),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  group('AdminShell responsive behavior', () {
    testWidgets('desktop shows expanded navigation rail (256px)', (tester) async {
      await pumpAdminShell(tester, viewport: const Size(1440, 900));

      expect(find.byType(AdminNavigationRail), findsOneWidget);
      expect(find.text('Akshara ERP'), findsOneWidget);
      expect(find.byType(AdminModulePlaceholderScreen), findsOneWidget);
    });

    testWidgets('tablet shows collapsed navigation rail (72px)', (tester) async {
      await pumpAdminShell(tester, viewport: const Size(1024, 768));

      expect(find.byType(AdminNavigationRail), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('mobile uses drawer navigation', (tester) async {
      await pumpAdminShell(tester, viewport: const Size(390, 844));

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('Admissions'), findsOneWidget);
    });
  });
}
