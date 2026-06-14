import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ai_access_preferences.dart';

const kAiAccessPreferencesKeyPrefix = 'ai_access_preferences_v1';

String aiAccessPreferencesStorageKey(String userId) =>
    '${kAiAccessPreferencesKeyPrefix}_$userId';

/// Local persistence for AI access preferences (device sync via backend is future work).
class AiAccessPreferencesStorage {
  AiAccessPreferencesStorage(this._prefs);

  final SharedPreferences _prefs;

  AiAccessPreferences readSync(String userId) {
    final raw = _prefs.getString(aiAccessPreferencesStorageKey(userId));
    if (raw == null || raw.isEmpty) {
      return const AiAccessPreferences();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const AiAccessPreferences();
      }
      return AiAccessPreferences.fromJson(decoded);
    } on Object {
      return const AiAccessPreferences();
    }
  }

  Future<void> write(String userId, AiAccessPreferences preferences) async {
    await _prefs.setString(
      aiAccessPreferencesStorageKey(userId),
      jsonEncode(preferences.toJson()),
    );
  }
}
