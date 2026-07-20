import 'package:shared_preferences/shared_preferences.dart';

/// P1-SEC-1 — local persistence for the biometric App Lock preference. Device-
/// level (not per-user): the lock must arm before any account is known and is a
/// device choice. Mirrors ThemeModePreferenceStorage.
const kAppLockEnabledKey = 'app_lock_enabled_v1';

class AppLockStorage {
  AppLockStorage(this._prefs);

  final SharedPreferences _prefs;

  bool readEnabled() => _prefs.getBool(kAppLockEnabledKey) ?? false;

  Future<void> writeEnabled(bool enabled) async {
    await _prefs.setBool(kAppLockEnabledKey, enabled);
  }
}
