import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/theme/theme_mode_provider.dart';
import 'package:akshara_erp/theme/theme_mode_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('themeModeStorageKey round-trip', () {
    test('every ThemeMode maps to a stable key and back', () {
      for (final mode in ThemeMode.values) {
        expect(themeModeFromStorageKey(themeModeStorageKey(mode)), mode);
      }
    });

    test('unknown / null keys decode to null', () {
      expect(themeModeFromStorageKey(null), isNull);
      expect(themeModeFromStorageKey('bogus'), isNull);
    });
  });

  group('ThemeModePreferenceStorage', () {
    test('defaults to light when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(ThemeModePreferenceStorage(prefs).readSync(), ThemeMode.light);
    });

    test('persists and reads back the chosen mode', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = ThemeModePreferenceStorage(prefs);
      await storage.write(ThemeMode.dark);
      expect(storage.readSync(), ThemeMode.dark);
      // A fresh storage over the same prefs sees the persisted value.
      expect(ThemeModePreferenceStorage(prefs).readSync(), ThemeMode.dark);
    });
  });

  group('themeModeProvider', () {
    Future<ProviderContainer> containerWith(
      Map<String, Object> initial,
    ) async {
      SharedPreferences.setMockInitialValues(initial);
      final prefs = await SharedPreferences.getInstance();
      return ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    }

    test('initial state reflects persisted preference', () async {
      final container = await containerWith(
        {kThemeModePreferenceKey: 'dark'},
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('initial state is light by default', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('setThemeMode updates state and persists', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.system);

      expect(container.read(themeModeProvider), ThemeMode.system);
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString(kThemeModePreferenceKey), 'system');
    });
  });
}
