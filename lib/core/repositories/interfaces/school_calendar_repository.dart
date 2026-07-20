import '../../../features/management/school_calendar/school_calendar_models.dart';
import '../repository_query.dart';

/// PRA-P1-17 — client contract for the school holiday/event calendar.
///
/// Backed by the Phase-1 backend under
/// `supabase/functions/_shared/school_calendar/*`:
///   * `GET    /school-calendar?from=&to=&eventType=` (perm `viewSchoolCalendar`)
///   * `POST   /school-calendar`                       (perm `manageSchoolCalendar`)
///   * `DELETE /school-calendar/{id}`                  (perm `manageSchoolCalendar`)
abstract class SchoolCalendarRepository {
  Future<List<SchoolCalendarEvent>> listEvents({
    required RepositoryQuery query,
    DateTime? from,
    DateTime? to,
    SchoolCalendarEventType? eventType,
  });

  Future<SchoolCalendarEvent> createEvent({
    required RepositoryQuery query,
    required CreateSchoolCalendarEventInput input,
  });

  Future<void> deleteEvent({
    required RepositoryQuery query,
    required String id,
  });
}
