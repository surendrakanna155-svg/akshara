import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/settings/appearance_settings_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const AppearanceSettingsScreen(),
        ),
      ),
    );
    return container;
  }

  testWidgets('shows all three appearance options', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(QaTestKeys.appearanceModeOption('light')), findsOneWidget);
    expect(find.byKey(QaTestKeys.appearanceModeOption('dark')), findsOneWidget);
    expect(
        find.byKey(QaTestKeys.appearanceModeOption('system')), findsOneWidget);
  });

  testWidgets('tapping Dark updates the theme-mode provider and persists',
      (tester) async {
    final container = await pumpScreen(tester);
    expect(container.read(themeModeProvider), ThemeMode.light);

    await tester.tap(find.byKey(QaTestKeys.appearanceModeOption('dark')));
    await tester.pump();

    expect(container.read(themeModeProvider), ThemeMode.dark);

    // A fresh container over the same prefs reads back the persisted choice.
    final prefs = container.read(sharedPreferencesProvider);
    final reread = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(reread.dispose);
    expect(reread.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('tapping System then Light tracks the selection', (tester) async {
    final container = await pumpScreen(tester);

    await tester.tap(find.byKey(QaTestKeys.appearanceModeOption('system')));
    await tester.pump();
    expect(container.read(themeModeProvider), ThemeMode.system);

    await tester.tap(find.byKey(QaTestKeys.appearanceModeOption('light')));
    await tester.pump();
    expect(container.read(themeModeProvider), ThemeMode.light);
  });
}
