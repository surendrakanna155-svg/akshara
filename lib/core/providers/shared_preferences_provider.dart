import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application [SharedPreferences] instance — must be overridden in [main].
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'sharedPreferencesProvider is uninitialized. '
    'Override it in main() after SharedPreferences.getInstance().',
  );
});
