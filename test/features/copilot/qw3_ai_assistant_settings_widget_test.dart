import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/copilot/settings/ai_access_mode.dart';
import 'package:akshara_erp/features/copilot/settings/ai_access_preferences_provider.dart';
import 'package:akshara_erp/features/copilot/settings/ai_assistant_settings_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';
import '../../test_helpers.dart';

/// QW3 · QA-F-053 — Settings → AI Assistant access-mode preferences (INTEL-05).
/// `ai_assistant_settings_screen.dart` lets the user pick a primary AI surface
/// and toggle the floating bubble. Covers: render of every access mode, the
/// floating-bubble switch, and that selecting a mode / flipping the switch
/// updates the persisted preference state (checkmark + switch value follow).

void main() {
  group('QA-F-053 · AiAssistantSettingsScreen', () {
    // Each test gets its own container so we can read the preference notifier
    // after interacting with the screen (proves the toggle persisted to state).
    Future<ProviderContainer> pump(WidgetTester tester) async {
      await initProviderTestPrefs();
      final container = ProviderContainer(
        overrides: erpWidgetTestOverrides(),
      );
      addTearDown(container.dispose);
      useMobileViewport(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const AiAssistantSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('renders every access mode option and the bubble toggle',
        (tester) async {
      await pump(tester);

      expect(find.text('AI Assistant'), findsOneWidget);
      expect(find.text('Access mode'), findsOneWidget);
      for (final mode in AiAccessMode.values) {
        expect(
          find.byKey(QaTestKeys.aiAccessModeOption(mode.storageKey)),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(QaTestKeys.aiAccessFloatingBubbleToggle),
        findsOneWidget,
      );
      expect(find.byKey(QaTestKeys.aiAccessSyncNote), findsOneWidget);
    });

    testWidgets('selecting a different access mode persists the choice',
        (tester) async {
      final container = await pump(tester);

      final initial = container.read(aiAccessPreferencesProvider).mode;
      // Pick a mode that differs from the current one so the change is real.
      final target = AiAccessMode.values.firstWhere((m) => m != initial);

      await tester.tap(find.byKey(QaTestKeys.aiAccessModeOption(target.storageKey)));
      await tester.pumpAndSettle();

      expect(container.read(aiAccessPreferencesProvider).mode, target);
      // The selected row shows the check marker.
      final selectedTile = tester.widget<ListTile>(
        find.byKey(QaTestKeys.aiAccessModeOption(target.storageKey)),
      );
      expect(selectedTile.trailing, isA<Icon>());
      expect((selectedTile.trailing! as Icon).icon, Icons.check_circle);
    });

    testWidgets('toggling the floating bubble flips the persisted flag',
        (tester) async {
      final container = await pump(tester);

      final before = container.read(aiAccessPreferencesProvider).floatingBubbleEnabled;
      await tester.tap(find.byKey(QaTestKeys.aiAccessFloatingBubbleToggle));
      await tester.pumpAndSettle();

      expect(
        container.read(aiAccessPreferencesProvider).floatingBubbleEnabled,
        !before,
      );
      final switchTile = tester.widget<SwitchListTile>(
        find.byKey(QaTestKeys.aiAccessFloatingBubbleToggle),
      );
      expect(switchTile.value, !before);
    });
  });
}
