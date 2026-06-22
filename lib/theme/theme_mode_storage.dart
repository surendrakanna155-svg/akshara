import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key for the app-wide appearance (theme-mode) preference.
///
/// Device-level (not per-user): the theme must apply on the login screen
/// before any account is known, and it is a device preference rather than an
/// account one. Mirrors the persistence pattern of
/// `ai_access_preferences_storage.dart`.
const kThemeModePreferenceKey = 'theme_mode_preference_v1';

/// Stable storage strings for [ThemeMode] (decoupled from enum index/order).
String themeModeStorageKey(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => 'system',
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
  };
}

ThemeMode? themeModeFromStorageKey(String? key) {
  return switch (key) {
    'system' => ThemeMode.system,
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => null,
  };
}

/// Local persistence for the appearance preference.
class ThemeModePreferenceStorage {
  ThemeModePreferenceStorage(this._prefs);

  final SharedPreferences _prefs;

  /// Reads the saved appearance, defaulting to [ThemeMode.light] — the
  /// owner-approved premium default (Phase A built light first).
  ThemeMode readSync() {
    return themeModeFromStorageKey(_prefs.getString(kThemeModePreferenceKey)) ??
        ThemeMode.light;
  }

  Future<void> write(ThemeMode mode) async {
    await _prefs.setString(kThemeModePreferenceKey, themeModeStorageKey(mode));
  }
}
