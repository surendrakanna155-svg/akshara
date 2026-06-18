import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Durable mock/API-offline storage for [ExamAdministrationStore] (P0-EXAM-004).
const kExamAdministrationStorageKey = 'akshara_exam_admin_v1';

/// Pre-M-A3 sync store key — migrated automatically on first load.
const kLegacyExamResultsStorageKey = 'akshara_exam_results_sync_v1';

class ExamAdministrationPersistence {
  ExamAdministrationPersistence(this._prefs);

  final SharedPreferences _prefs;

  Map<String, dynamic>? loadSnapshot() {
    final current = _decodeSnapshot(_prefs.getString(kExamAdministrationStorageKey));
    if (current != null) return current;

    final migrated = _migrateLegacySnapshot();
    if (migrated != null) {
      saveSnapshot(migrated);
      _prefs.remove(kLegacyExamResultsStorageKey);
    }
    return migrated;
  }

  Map<String, dynamic>? _decodeSnapshot(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } on Object {
      return null;
    }
  }

  /// Imports published results from the legacy [MockExamResultsSyncStore] key.
  Map<String, dynamic>? _migrateLegacySnapshot() {
    final legacy = _decodeSnapshot(_prefs.getString(kLegacyExamResultsStorageKey));
    if (legacy == null) return null;

    final published = legacy['published'];
    if (published is! List || published.isEmpty) return null;

    return {
      'version': 1,
      'exams': legacy['exams'] is List ? legacy['exams'] : <dynamic>[],
      'marks': legacy['marks'] is List ? legacy['marks'] : <dynamic>[],
      'published': published,
      'rejectionComments': <String, String>{},
      'coordinatorVerified': <String, String>{},
      'migratedFrom': kLegacyExamResultsStorageKey,
    };
  }

  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    await _prefs.setString(
      kExamAdministrationStorageKey,
      jsonEncode(snapshot),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(kExamAdministrationStorageKey);
  }
}
