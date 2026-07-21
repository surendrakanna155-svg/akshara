import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/copilot/settings/ai_access_mode.dart';
import 'package:akshara_erp/features/copilot/settings/ai_access_preferences.dart';
import 'package:akshara_erp/features/copilot/settings/ai_access_preferences_provider.dart';
import 'package:akshara_erp/features/parent/shell/parent_shell.dart';
import 'package:akshara_erp/shared/navigation/persona_nav.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test_helpers.dart';

/// UXR-G2 (P0) regression: with the AI access mode set to bottom-nav center, the
/// raised AI affordance must NOT paint over or intercept taps for the centre
/// primary destination (parent Fees / teacher Teach / student Schedule). Every
/// primary tab must dispatch its own route, and the AI button must remain
/// present (Goal B) but sit clear of the destination row (Goal A).
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

  Future<void> pump(WidgetTester tester, String initial) async {
    useMobileViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        // Force the on-bar AI center affordance on so the overlap scenario is
        // exercised deterministically regardless of role/env/stored prefs.
        overrides: erpWidgetTestOverrides([
          aiAccessPreferencesProvider.overrideWith(_ForcedBottomNavAiPrefs.new),
        ]),
        child: MaterialApp.router(
          theme: AksharaAppTheme.light(),
          routerConfig: routerAt(initial),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'the AI affordance is present but sits clear of the destination row',
      (tester) async {
    await pump(tester, spec.primary.first.route);

    // Goal B: the AI affordance is still available on the bar.
    final fab = find.byKey(QaTestKeys.copilotAiEntryButton);
    expect(fab, findsOneWidget);

    // Goal A: it never covers a destination — its whole hit region is above the
    // bar's top edge, so no NavigationDestination lives under it.
    final barTop = tester.getRect(find.byType(NavigationBar)).top;
    final fabRect = tester.getRect(fab);
    expect(
      fabRect.bottom,
      lessThanOrEqualTo(barTop + 0.5),
      reason: 'the AI button must not dip into the NavigationBar and steal a '
          'nav-tab tap (UXR-G2)',
    );
  });

  testWidgets(
      'every primary destination is independently tappable and routes to its '
      'own screen (AI does not intercept the centre tab)', (tester) async {
    for (var i = 0; i < spec.primary.length; i++) {
      // Start on a *different* primary so destination i is unselected and shows
      // its own (outlined) icon, then tap that icon directly — the exact spot
      // the AI button used to cover for the centre tab.
      final startIndex = (i + 1) % spec.primary.length;
      await pump(tester, spec.primary[startIndex].route);

      await tester.tap(find.byIcon(spec.primary[i].icon));
      await tester.pumpAndSettle();

      expect(
        find.text('SCREEN ${spec.primary[i].route}'),
        findsOneWidget,
        reason: '${spec.primary[i].label} tab (index $i) must dispatch its own '
            'route; the AI affordance must not intercept its tap (UXR-G2)',
      );
    }
  });
}

/// Pins the AI access preference to the on-bar centre mode for the test.
class _ForcedBottomNavAiPrefs extends AiAccessPreferencesNotifier {
  @override
  AiAccessPreferences build() =>
      const AiAccessPreferences(mode: AiAccessMode.bottomNavCenter);
}
