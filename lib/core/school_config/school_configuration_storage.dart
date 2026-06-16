import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'school_configuration_models.dart';

const kSchoolConfigurationStorageKey = 'akshara_school_configuration_v1';

class SchoolConfigurationStorage {
  SchoolConfigurationStorage(this._prefs);

  final SharedPreferences _prefs;

  SchoolConfiguration? readSync() {
    final raw = _prefs.getString(kSchoolConfigurationStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return SchoolConfiguration.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  Future<void> write(SchoolConfiguration config) async {
    await _prefs.setString(
      kSchoolConfigurationStorageKey,
      jsonEncode(config.toJson()),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(kSchoolConfigurationStorageKey);
  }
}
