import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/parent/shell/parent_shell.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/shared/navigation/persona_nav.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';

/// Widget-level coverage for the shared persona bottom nav: the "More" tab,
/// its sheet, route-aware selection, and the multi-hat workspace switcher
/// surfaced inside the sheet (UX Batch 2).
void main() {
  const spec = ParentShell.navSpec;

  GoRouter routerAt(String initial) {
    final paths = <String>{
      ...spec.primary.map((d) => d.route),
      ...spec.more.map((d) => d.route),
    };
    return GoRouter(
      initialLocation: initial,
      routes: [
        for (final path in paths)
          GoRoute(
            path: path,
            builder: (context, state) => Scaffold(
              body: Center(child: Text('SCREEN $path')),
              bottomNavigationBar: const PersonaBottomNav(spec: spec),
            ),
          ),
      ],
    );
  }

  Future<void> pump(
    WidgetTester tester,
    String initial, {
    List<Override> extra = const [],
  }) async {
    useMobileViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: erpWidgetTestOverrides(extra),
        child: MaterialApp.router(
          theme: AksharaAppTheme.light(),
          routerConfig: routerAt(initial),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  NavigationBar navBar(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar));

  testWidgets('renders 4 primary tabs + a More tab', (tester) async {
    await pump(tester, RouteNames.parentDashboard);

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byKey(QaTestKeys.moreNavTab), findsOneWidget);
    expect(navBar(tester).selectedIndex, 0);
  });

  testWidgets('More tab opens a sheet listing the secondary screens',
      (tester) async {
    await pump(tester, RouteNames.parentDashboard);

    await tester.tap(find.byKey(QaTestKeys.moreNavTab));
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.moreNavSheet), findsOneWidget);
    for (final label in ['Leave', 'Notices', 'Events', 'PTM', 'Transport',
      'Profile']) {
      expect(find.byKey(QaTestKeys.moreNavSheetItem(label)), findsOneWidget,
          reason: '$label should appear in the More sheet');
    }
  });

  testWidgets('tapping a More item navigates and closes the sheet',
      (tester) async {
    await pump(tester, RouteNames.parentDashboard);

    await tester.tap(find.byKey(QaTestKeys.moreNavTab));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QaTestKeys.moreNavSheetItem('Notices')));
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.moreNavSheet), findsNothing);
    expect(find.text('SCREEN ${RouteNames.parentNotices}'), findsOneWidget);
    // A More destination lights the More tab (last slot), not Home.
    expect(navBar(tester).selectedIndex, spec.primary.length);
  });

  testWidgets('a secondary route highlights the More tab, not Home',
      (tester) async {
    await pump(tester, RouteNames.parentTransport);
    expect(navBar(tester).selectedIndex, spec.primary.length);
  });

  testWidgets('primary routes highlight their own tab', (tester) async {
    await pump(tester, RouteNames.parentMessages);
    // Messages is the 4th primary tab (index 3) — the promoted decision.
    expect(navBar(tester).selectedIndex, 3);
  });

  testWidgets('More sheet surfaces the workspace switcher for multi-hat users',
      (tester) async {
    await pump(
      tester,
      RouteNames.parentDashboard,
      extra: [
        userPermissionsProvider.overrideWithValue(
          UserPermissions.forRoles(
            const [ErpRole.inventoryManager, ErpRole.teacher],
          ),
        ),
      ],
    );

    await tester.tap(find.byKey(QaTestKeys.moreNavTab));
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.workspaceSwitcher), findsOneWidget);
  });

  testWidgets('single-workspace users see no switcher in the More sheet',
      (tester) async {
    await pump(tester, RouteNames.parentDashboard);

    await tester.tap(find.byKey(QaTestKeys.moreNavTab));
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.moreNavSheet), findsOneWidget);
    expect(find.byKey(QaTestKeys.workspaceSwitcher), findsNothing);
  });
}
