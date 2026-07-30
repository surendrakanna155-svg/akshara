import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/copilot/dock/copilot_dock_host.dart';
import 'package:akshara_erp/features/copilot/settings/ai_access_mode.dart';
import 'package:akshara_erp/features/copilot/settings/ai_access_preferences.dart';
import 'package:akshara_erp/features/copilot/settings/ai_access_preferences_provider.dart';
import 'package:akshara_erp/features/copilot/widgets/bottom_nav_ai_scope.dart';
import 'package:akshara_erp/shared/layout/bottom_chrome_scope.dart';
import 'package:akshara_erp/shared/navigation/persona_nav.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/breakpoints.dart';
import 'package:akshara_erp/theme/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/auth_test_overrides.dart';

// Tablet-width regression: the floating AI dock must sit clear of the persona
// bottom navigation bar at EVERY width, not just on phones.
//
// The dock used to derive its bottom inset from a width tier
// (`isMobile ? 88 : 24`), which assumed a bottom nav exists only on phones.
// The persona shells have no tablet branch — they paint the same 80dp
// [NavigationBar] on tablets — so at tablet width the dock dropped into the
// bar and covered a primary destination, reading on screen as a second,
// broken AI button next to the raised centre one.
//
// The bar now publishes its measured height via [BottomChromeScope] and the
// dock clears it, so any shell that paints a bottom nav is handled without the
// overlay knowing anything about breakpoints.

/// Mirrors the private `_moreTileMaxExtent` cap in `persona_nav.dart`.
const double _moreTileMaxExtentCeiling = 140;

void main() {
  const spec = PersonaNavSpec(
    primary: [
      PersonaNavDestination(
        route: '/home',
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      PersonaNavDestination(
        route: '/academics',
        label: 'Academics',
        icon: Icons.school_outlined,
        selectedIcon: Icons.school,
      ),
    ],
    more: [
      MoreNavDestination(
        route: '/notices',
        label: 'Notices',
        icon: Icons.campaign_outlined,
      ),
      MoreNavDestination(
        route: '/leave',
        label: 'Leave',
        icon: Icons.event_busy_outlined,
      ),
      MoreNavDestination(
        route: '/transport',
        label: 'Transport',
        icon: Icons.directions_bus_outlined,
      ),
      MoreNavDestination(
        route: '/profile',
        label: 'Profile',
        icon: Icons.person_outline,
      ),
    ],
  );

  /// A persona shell in miniature: bottom nav + the dock stacked beside it,
  /// exactly as the router composes `CopilotDockHost(child: <PersonaShell>)`.
  Future<void> pumpShell(WidgetTester tester, Size viewport) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateOverride(erpWidgetTestStaffAuth()),
          aiAccessPreferencesProvider.overrideWith(_BothAiEntriesPrefs.new),
        ],
        child: MaterialApp.router(
          theme: AksharaAppTheme.light(),
          routerConfig: GoRouter(
            initialLocation: '/home',
            routes: [
              ShellRoute(
                builder: (context, state, child) => CopilotDockHost(
                  child: Consumer(
                    builder: (context, ref, _) => BottomNavAiScope(
                      reservedHeight:
                          BottomNavAiScope.resolveHeight(context, ref),
                      child: Scaffold(
                        body: child,
                        bottomNavigationBar:
                            const PersonaBottomNav(spec: spec),
                      ),
                    ),
                  ),
                ),
                routes: [
                  for (final path in <String>{
                    ...spec.primary.map((d) => d.route),
                    ...spec.more.map((d) => d.route),
                  })
                    GoRoute(
                      path: path,
                      builder: (_, __) => const SizedBox.expand(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const viewports = <({String label, Size size})>[
    (label: 'phone', size: Size(428, 926)),
    // 834x1194 — the iPad width the overlap was reported at.
    (label: 'tablet', size: Size(834, 1194)),
  ];

  for (final viewport in viewports) {
    testWidgets(
      'floating AI dock stays clear of the bottom nav at '
      '${viewport.label} width (${viewport.size.width.toInt()}dp)',
      (tester) async {
        await pumpShell(tester, viewport.size);

        final barFinder = find.byType(NavigationBar);
        final dockFinder = find.byKey(QaTestKeys.copilotFloatingDockFab);
        expect(barFinder, findsOneWidget);
        expect(dockFinder, findsOneWidget);

        final bar = tester.getRect(barFinder);
        final dock = tester.getRect(dockFinder);

        expect(
          dock.bottom,
          lessThanOrEqualTo(bar.top),
          reason: 'the floating AI dock must not paint into the navigation '
              'bar and cover a primary destination at ${viewport.label} width',
        );
        expect(
          dock.overlaps(bar),
          isFalse,
          reason: 'dock $dock overlaps nav bar $bar',
        );
      },
    );
  }

  testWidgets('the nav bar publishes its measured height to the scope',
      (tester) async {
    await pumpShell(tester, const Size(834, 1194));

    final barHeight = tester.getRect(find.byType(NavigationBar)).height;
    final dockContext = tester.element(
      find.byKey(QaTestKeys.copilotFloatingDockFab),
    );

    expect(
      BottomChromeScope.maybeHeightOf(dockContext),
      barHeight,
      reason: 'the reported chrome is the bar as laid out, not a constant — '
          'so safe-area/gesture insets are carried automatically',
    );
  });

  testWidgets('reports nothing outside a scope, leaving callers their fallback',
      (tester) async {
    late BuildContext probe;
    await tester.pumpWidget(
      MaterialApp(
        home: BottomChromeReporter(
          child: Builder(
            builder: (context) {
              probe = context;
              return const SizedBox(height: 80);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(BottomChromeScope.maybeHeightOf(probe), isNull);
  });

  testWidgets('clears its report when the nav bar leaves the tree',
      (tester) async {
    late BuildContext probe;

    Widget host({required bool showNav}) => MaterialApp(
          home: BottomChromeScope(
            child: Builder(
              builder: (context) {
                probe = context;
                if (!showNav) return const SizedBox.shrink();
                // Bottom-aligned so the stand-in bar keeps its own 80dp height
                // instead of being stretched by the route's tight constraints.
                return const Align(
                  alignment: Alignment.bottomCenter,
                  child: BottomChromeReporter(
                    child: SizedBox(width: double.infinity, height: 80),
                  ),
                );
              },
            ),
          ),
        );

    await tester.pumpWidget(host(showNav: true));
    await tester.pumpAndSettle();
    expect(BottomChromeScope.maybeHeightOf(probe), 80);

    await tester.pumpWidget(host(showNav: false));
    await tester.pumpAndSettle();
    expect(
      BottomChromeScope.maybeHeightOf(probe),
      isNull,
      reason: 'a shell that drops its bottom nav must stop reserving space',
    );
  });

  group('More sheet tiles stay phone-sized as the surface grows', () {
    /// The sheet had a fixed 3-column grid, so on a tablet — where the sheet
    /// widens to its 640dp cap — each tile inflated to ~192x209dp around a 44dp
    /// icon. Tiles are now extent-capped: the phone layout is unchanged and
    /// wider surfaces gain columns instead.
    Future<Size> tileSizeAt(WidgetTester tester, Size viewport) async {
      await pumpShell(tester, viewport);
      await tester.tap(find.byKey(QaTestKeys.moreNavTab));
      await tester.pumpAndSettle();
      return tester.getSize(
        find.byKey(QaTestKeys.moreNavSheetItem('Notices')),
      );
    }

    testWidgets('phone tile geometry is unchanged', (tester) async {
      final tile = await tileSizeAt(tester, const Size(428, 926));
      // 428dp − 40dp sheet padding = 388dp, minus 2 gaps of 12dp, over 3
      // columns — exactly what the old fixed 3-column grid produced.
      expect(tile.width, closeTo((388 - 24) / 3, 0.5));
    });

    testWidgets('tablet tile is not inflated', (tester) async {
      final phone = await tileSizeAt(tester, const Size(428, 926));
      final tablet = await tileSizeAt(tester, const Size(834, 1194));

      expect(
        tablet.width,
        // `GridView.extent` rounds the column count UP, so the realised tile
        // can sit a little above the cap; it can never approach the ~192dp the
        // old fixed 3-column grid produced here.
        lessThan(_moreTileMaxExtentCeiling + AksharaSpacing.s4),
        reason: 'a More tile must stay phone-sized on a tablet, not stretch '
            'to a third of the screen around a 44dp icon',
      );
      expect(
        (tablet.width - phone.width).abs(),
        lessThan(24),
        reason: 'tile size should be roughly constant across widths; only the '
            'number of columns changes',
      );
    });
  });

  test('tablet width still resolves to the tablet tier', () {
    // Guards the premise of the regression: 834dp is a tablet, and the persona
    // shells keep their bottom nav there.
    expect(AksharaBreakpoints.fromWidth(834), LayoutBreakpoint.tablet);
  });
}

/// Pins BOTH AI entry points on: the raised centre button (bottom-nav centre
/// mode) and the optional floating bubble. This is the QA/demo configuration
/// the tablet overlap was screenshotted in.
class _BothAiEntriesPrefs extends AiAccessPreferencesNotifier {
  @override
  AiAccessPreferences build() => const AiAccessPreferences(
        mode: AiAccessMode.bottomNavCenter,
        floatingBubbleEnabled: true,
      );
}
