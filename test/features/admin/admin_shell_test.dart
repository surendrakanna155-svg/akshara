import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/admin/admin_bottom_nav.dart';
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
      expect(find.text('NIKSHA OS'), findsOneWidget);
      expect(find.byType(AdminModulePlaceholderScreen), findsOneWidget);
    });

    testWidgets('expanded rail scrolls on short desktop viewport without overflow',
        (tester) async {
      await pumpAdminShell(tester, viewport: const Size(1280, 600));

      expect(find.byType(AdminNavigationRail), findsOneWidget);
      expect(find.byType(ListView), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet shows collapsed navigation rail (72px)', (tester) async {
      await pumpAdminShell(tester, viewport: const Size(1024, 768));

      expect(find.byType(AdminNavigationRail), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('mobile shows a bottom nav with a reachable module drawer',
        (tester) async {
      await pumpAdminShell(tester, viewport: const Size(390, 844));

      // No Material NavigationRail on phones; admin now gets a bottom nav
      // (parity with the consumer apps — MOBILE_FIRST_AUDIT #3).
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(AdminBottomNav), findsOneWidget);
      expect(find.byKey(QaTestKeys.adminBottomNavMore), findsOneWidget);

      // Both the app-bar menu and the More tab open the full module drawer.
      expect(find.byIcon(Icons.menu), findsOneWidget);

      // Admissions is one of the (≤4) bottom-nav tabs → visible once.
      expect(find.text('Admissions'), findsOneWidget);

      // Opening the drawer surfaces the full module list, so Admissions now
      // appears in both the bottom nav and the drawer rail.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.text('Admissions'), findsNWidgets(2));
    });

    testWidgets('tablet and desktop do not show the mobile bottom nav',
        (tester) async {
      await pumpAdminShell(tester, viewport: const Size(1024, 768));
      expect(find.byType(AdminBottomNav), findsNothing);

      await pumpAdminShell(tester, viewport: const Size(1440, 900));
      expect(find.byType(AdminBottomNav), findsNothing);
    });
  });
}
