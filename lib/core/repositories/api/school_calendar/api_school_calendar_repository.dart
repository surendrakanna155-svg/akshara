import '../../../../features/management/school_calendar/school_calendar_models.dart';
import '../../interfaces/school_calendar_repository.dart';
import '../../repository_query.dart';
import 'remote/school_calendar_remote_datasource.dart';

/// API-backed [SchoolCalendarRepository]. Thin pass-through to the remote
/// datasource — the datasource owns the envelope/DTO mapping.
class ApiSchoolCalendarRepository implements SchoolCalendarRepository {
  ApiSchoolCalendarRepository({
    required SchoolCalendarRemoteDataSource remote,
  }) : _remote = remote;

  final SchoolCalendarRemoteDataSource _remote;

  @override
  Future<List<SchoolCalendarEvent>> listEvents({
    required RepositoryQuery query,
    DateTime? from,
    DateTime? to,
    SchoolCalendarEventType? eventType,
  }) =>
      _remote.fetchEvents(
        query: query,
        from: from,
        to: to,
        eventType: eventType,
      );

  @override
  Future<SchoolCalendarEvent> createEvent({
    required RepositoryQuery query,
    required CreateSchoolCalendarEventInput input,
  }) =>
      _remote.createEvent(query: query, input: input);

  @override
  Future<void> deleteEvent({
    required RepositoryQuery query,
    required String id,
  }) =>
      _remote.deleteEvent(query: query, id: id);
}
