/// PRA-P1-17 — Holiday/Event Calendar client models.
///
/// Mirrors the backend contract in
/// `supabase/functions/_shared/school_calendar/*`. The backend is the
/// school-scoped source of truth for holidays/events; downstream attendance
/// holiday-block and HR holiday-exclusion read from `school_calendar_events`.
library;

import 'package:flutter/foundation.dart';

/// Event types accepted by `POST /school-calendar` (`eventType`). The API value
/// is the enum [name] verbatim (`holiday`, `festival`, …). `holiday` is the
/// backend default.
enum SchoolCalendarEventType {
  holiday,
  festival,
  event,
  exam,
  result,
  admission,
  achievement,
  general;

  /// Wire value sent to / received from the backend.
  String get apiValue => name;

  /// Human-readable label for the UI.
  String get label => switch (this) {
        SchoolCalendarEventType.holiday => 'Holiday',
        SchoolCalendarEventType.festival => 'Festival',
        SchoolCalendarEventType.event => 'Event',
        SchoolCalendarEventType.exam => 'Exam',
        SchoolCalendarEventType.result => 'Result',
        SchoolCalendarEventType.admission => 'Admission',
        SchoolCalendarEventType.achievement => 'Achievement',
        SchoolCalendarEventType.general => 'General',
      };

  /// Parses a wire value; unknown values fall back to [general] so an
  /// unexpected server value never crashes the list.
  static SchoolCalendarEventType fromApi(String? value) {
    for (final type in SchoolCalendarEventType.values) {
      if (type.name == value) return type;
    }
    return SchoolCalendarEventType.general;
  }
}

/// A single calendar entry returned by `GET /school-calendar`.
@immutable
class SchoolCalendarEvent {
  const SchoolCalendarEvent({
    required this.id,
    required this.eventDate,
    required this.title,
    required this.eventType,
    this.endDate,
    this.description,
    this.createdAt,
  });

  final String id;

  /// Start date (date-only). Backend serialises as `YYYY-MM-DD`.
  final DateTime eventDate;

  /// Optional inclusive end date for multi-day events (date-only).
  final DateTime? endDate;

  final String title;
  final SchoolCalendarEventType eventType;
  final String? description;
  final DateTime? createdAt;

  /// True when the entry spans more than the start day.
  bool get isMultiDay => endDate != null && endDate!.isAfter(eventDate);

  @override
  bool operator ==(Object other) =>
      other is SchoolCalendarEvent &&
      other.id == id &&
      other.eventDate == eventDate &&
      other.endDate == endDate &&
      other.title == title &&
      other.eventType == eventType &&
      other.description == description &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        eventDate,
        endDate,
        title,
        eventType,
        description,
        createdAt,
      );
}

/// Input for `POST /school-calendar`. `eventDate` and `title` are required by
/// the backend.
@immutable
class CreateSchoolCalendarEventInput {
  const CreateSchoolCalendarEventInput({
    required this.eventDate,
    required this.title,
    this.eventType = SchoolCalendarEventType.holiday,
    this.endDate,
    this.description,
  });

  final DateTime eventDate;
  final DateTime? endDate;
  final String title;
  final SchoolCalendarEventType eventType;
  final String? description;
}
