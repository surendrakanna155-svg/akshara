import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/shared_preferences_provider.dart';
import 'theme_mode_storage.dart';

/// Storage accessor for the appearance preference. Null when
/// [sharedPreferencesProvider] has not been overridden (e.g. bare widget
/// tests); the real app overrides it in `main()`.
///
/// Reads the provider directly rather than gating on `ref.exists`, because the
/// theme is watched at the very top of `MaterialApp` build — earlier than any
/// other consumer of SharedPreferences — so an `exists` check would spuriously
/// return null on first launch.
final themeModePreferenceStorageProvider =
    Provider<ThemeModePreferenceStorage?>((ref) {
  try {
    return ThemeModePreferenceStorage(ref.watch(sharedPreferencesProvider));
  } on StateError {
    return null;
  }
});

/// App-wide appearance (Light / Dark / System). Drives `MaterialApp.themeMode`.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Resolves the effective [Brightness] a persona shell should build its theme
/// at, given the app-wide appearance [mode] and the current [platform]
/// brightness (used only when [mode] is [ThemeMode.system]). Lets each shell
/// honor the Appearance setting instead of forcing a fixed brightness (F-002).
Brightness resolveEffectiveBrightness(ThemeMode mode, Brightness platform) =>
    switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platform,
    };

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final storage = ref.read(themeModePreferenceStorageProvider);
    return storage?.readSync() ?? ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref.read(themeModePreferenceStorageProvider)?.write(mode);
  }
}
