import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/admin/admin_bottom_nav.dart';
import 'package:akshara_erp/features/admin/admin_shell.dart';
import 'package:akshara_erp/features/admin/models/admin_nav_models.dart';
import 'package:akshara_erp/features/admin/screens/admin_module_placeholder_screen.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/auth_test_overrides.dart';

/// QW7 · QA-C-004 — ERP / Admin shell *behaviour* certification (Batch 2).
///
/// Sits ON TOP of the existing admin-shell coverage which already proves the
/// responsive chrome (rail ↔ bottom-nav) and module rendering:
///   • test/features/admin/admin_shell_test.dart        (rail/bottom-nav per
///     breakpoint, menu opens the drawer, bottom-nav More tab present)
///   • test/features/admin/admin_navigation_provider_test.dart
///   • test/features/admin/workspace_scoped_nav_test.dart
///   • test/features/admin/global_search_registry_test.dart  (RBAC-filtered search)
///
/// This cert asserts the shell's two key clickable behaviours actually act:
///   1. tapping a bottom-nav module TAB NAVIGATES to that module's route (the
///      content swaps from one module's placeholder to the next), and
///   2. tapping the "More" tab OPENS the module drawer.
/// The canonical 4 async states belong to the per-module screens (swept by
/// qw6_state_sweep_test.dart / QA-C-008); the shell is navigation chrome, so its
/// behaviour cert is navigation + drawer, not data-state.
void _useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// A router that wires the real bottom-nav destination routes to module
/// placeholder screens, so a tab tap exercises the genuine `context.go(...)`.
GoRouter _shellRouter() {
  GoRoute moduleRoute(String path, AdminModule module) => GoRoute(
        path: path,
        builder: (_, __) => AdminModulePlaceholderScreen(module: module),
      );

  return GoRouter(
    initialLocation: RouteNames.admin,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          moduleRoute(RouteNames.admin, AdminModule.admin),
          moduleRoute(RouteNames.admissionsDashboard, AdminModule.admissions),
          moduleRoute(RouteNames.growthPlatform, AdminModule.marketing),
          moduleRoute(RouteNames.financeDashboard, AdminModule.finance),
        ],
      ),
    ],
  );
}

Future<void> _pumpShell(WidgetTester tester) async {
  _useViewport(tester, const Size(390, 844)); // phone → bottom nav is present
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
        routerConfig: _shellRouter(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QA-C-004 · Admin shell — clickable navigation behaviour', () {
    // Body-only markers (the module placeholder's description) prove WHICH module
    // is mounted, free of the tab-label / breadcrumb / header duplicates that the
    // module name produces in the chrome.
    const adminBody =
        'Web ERP foundation is ready. Module screens will be added in upcoming releases.';
    const admissionsBody =
        'Admissions CRM (AD-01 → AD-10) will be built on this shell. Not started yet.';

    testWidgets('tapping the Admissions tab navigates to the Admissions module',
        (tester) async {
      await _pumpShell(tester);

      // Starts on the Admin hub — its body is shown, the Admissions body is not.
      expect(find.byType(AdminBottomNav), findsOneWidget);
      expect(find.text(adminBody), findsOneWidget);
      expect(find.text(admissionsBody), findsNothing);

      // Tap the Admissions bottom-nav tab → router navigates and the placeholder
      // content swaps to the Admissions module.
      await tester.tap(find.byKey(
          QaTestKeys.adminBottomNavModule(AdminModule.admissions.name)));
      await tester.pumpAndSettle();

      // The Admin-hub body is gone; the Admissions module body is now mounted.
      expect(find.text(adminBody), findsNothing);
      expect(find.text(admissionsBody), findsOneWidget);
    });

    testWidgets('the More tab opens the module drawer', (tester) async {
      await _pumpShell(tester);

      expect(find.byKey(QaTestKeys.adminBottomNavMore), findsOneWidget);

      // Tap the More tab → the full module drawer opens.
      await tester.tap(find.byKey(QaTestKeys.adminBottomNavMore));
      await tester.pumpAndSettle();

      // The drawer surfaces the full module list (e.g. the Student SIS module,
      // which has no phone tab slot), proving the More tab opened it.
      expect(find.text('Student SIS'), findsWidgets);
    });
  });
}
