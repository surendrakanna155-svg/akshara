/// A persisted snapshot of an in-progress form, scoped to a user + school.
///
/// Saved automatically while a user is entering data (debounced + on app
/// background/lock) and offered back on return so work is never lost.
class DraftRecord {
  const DraftRecord({
    required this.key,
    required this.userId,
    required this.json,
    required this.updatedAt,
    this.schoolId,
    this.label,
  });

  /// Stable, entity-scoped key, e.g. `exam_marks:{examId}:{classId}`.
  final String key;

  /// Owner of the draft. Drafts are wiped on logout / user switch.
  final String userId;

  /// Optional tenant scope.
  final String? schoolId;

  /// The form snapshot (the form's own `toJson()`).
  final Map<String, dynamic> json;

  /// Human-readable label for the Sync Center / resume prompt.
  final String? label;

  final DateTime updatedAt;

  DraftRecord copyWith({
    Map<String, dynamic>? json,
    DateTime? updatedAt,
    String? label,
  }) {
    return DraftRecord(
      key: key,
      userId: userId,
      schoolId: schoolId,
      json: json ?? this.json,
      label: label ?? this.label,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'userId': userId,
        'schoolId': schoolId,
        'json': json,
        'label': label,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DraftRecord.fromJson(Map<String, dynamic> json) {
    return DraftRecord(
      key: json['key'] as String,
      userId: json['userId'] as String,
      schoolId: json['schoolId'] as String?,
      json: (json['json'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      label: json['label'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
