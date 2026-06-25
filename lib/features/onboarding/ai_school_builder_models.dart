import 'package:flutter/foundation.dart';

/// B7 — AI School Builder (Phase 1): the short founder brief sent to the
/// `/onboarding/startup/ai-prefill` endpoint and the proposal it returns.
///
/// The proposal is NON-DESTRUCTIVE — it is applied into the onboarding wizard
/// state for the admin to review and refine before saving / going live.
@immutable
class SchoolBrief {
  const SchoolBrief({
    this.schoolName = '',
    this.board = '',
    this.schoolType = '',
    this.address = '',
    this.contactPhone = '',
    this.contactEmail = '',
    this.lowestGrade = '',
    this.highestGrade = '',
    this.sectionsPerGrade,
    this.estimatedStudents,
    this.estimatedTeachers,
    this.languages = const [],
    this.interestedModules = const [],
    this.notes = '',
  });

  final String schoolName;
  final String board;
  final String schoolType;
  final String address;
  final String contactPhone;
  final String contactEmail;
  final String lowestGrade;
  final String highestGrade;
  final int? sectionsPerGrade;
  final int? estimatedStudents;
  final int? estimatedTeachers;
  final List<String> languages;
  final List<String> interestedModules;
  final String notes;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    void put(String key, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is List && value.isEmpty) return;
      json[key] = value;
    }

    put('schoolName', schoolName);
    put('board', board);
    put('schoolType', schoolType);
    put('address', address);
    put('contactPhone', contactPhone);
    put('contactEmail', contactEmail);
    put('lowestGrade', lowestGrade);
    put('highestGrade', highestGrade);
    put('sectionsPerGrade', sectionsPerGrade);
    put('estimatedStudents', estimatedStudents);
    put('estimatedTeachers', estimatedTeachers);
    put('languages', languages);
    put('interestedModules', interestedModules);
    put('notes', notes);
    return json;
  }
}

/// Outcome of an AI pre-fill: where the proposal came from + why + caveats.
@immutable
class SchoolBlueprintResult {
  const SchoolBlueprintResult({
    required this.source,
    required this.rationale,
    required this.warnings,
  });

  /// "ai" when Claude refined the proposal, "deterministic" on fallback.
  final String source;
  final String rationale;
  final List<String> warnings;

  bool get isAi => source == 'ai';

  factory SchoolBlueprintResult.fromJson(Map<String, dynamic> json) {
    return SchoolBlueprintResult(
      source: json['source'] as String? ?? 'deterministic',
      rationale: json['rationale'] as String? ?? '',
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}
