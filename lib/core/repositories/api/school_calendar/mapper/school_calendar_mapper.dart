import '../../../../../features/management/school_calendar/school_calendar_models.dart';

/// Maps the backend `{ id, eventDate, endDate, title, eventType, description,
/// createdAt }` shape to/from [SchoolCalendarEvent]. `eventDate`/`endDate` are
/// date-only (`YYYY-MM-DD`); `createdAt` is an ISO-8601 timestamp.
class SchoolCalendarMapper {
  const SchoolCalendarMapper();

  SchoolCalendarEvent toDomain(Map<String, dynamic> json) {
    return SchoolCalendarEvent(
      id: json['id'] as String,
      eventDate: _parseDate(json['eventDate']) ?? DateTime(1970),
      endDate: _parseDate(json['endDate']),
      title: json['title'] as String? ?? '',
      eventType: SchoolCalendarEventType.fromApi(json['eventType'] as String?),
      description: json['description'] as String?,
      createdAt: _parseDate(json['createdAt']),
    );
  }

  List<SchoolCalendarEvent> toDomainList(List<dynamic> items) => items
      .whereType<Map<String, dynamic>>()
      .map(toDomain)
      .toList(growable: false);

  Map<String, dynamic> createBody(CreateSchoolCalendarEventInput input) {
    return {
      'eventDate': formatDate(input.eventDate),
      if (input.endDate != null) 'endDate': formatDate(input.endDate!),
      'title': input.title,
      'eventType': input.eventType.apiValue,
      if (input.description != null && input.description!.trim().isNotEmpty)
        'description': input.description!.trim(),
    };
  }

  /// `YYYY-MM-DD` — the date-only wire format the backend stores.
  static String formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
