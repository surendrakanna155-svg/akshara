import '../../../features/management/school_calendar/school_calendar_models.dart';
import '../interfaces/school_calendar_repository.dart';
import '../repository_query.dart';

/// In-memory store so add/delete persist across widget rebuilds in mock/dev
/// builds (matching the peer `*Store.instance` mock convention). Not used in API
/// mode.
class SchoolCalendarMockStore {
  /// Empty store — used by tests for a deterministic starting point.
  SchoolCalendarMockStore.empty();

  /// Store pre-populated with demo holidays (the default dev/mock experience).
  factory SchoolCalendarMockStore.seeded() {
    final store = SchoolCalendarMockStore.empty();
    store._seed();
    return store;
  }

  static final SchoolCalendarMockStore instance =
      SchoolCalendarMockStore.seeded();

  final List<SchoolCalendarEvent> _events = [];
  int _seq = 0;

  void _seed() {
    final year = DateTime.now().year;
    _events.addAll([
      SchoolCalendarEvent(
        id: _nextId(),
        eventDate: DateTime(year, 1, 26),
        title: 'Republic Day',
        eventType: SchoolCalendarEventType.holiday,
        description: 'National holiday — school closed.',
        createdAt: DateTime(year, 1, 1),
      ),
      SchoolCalendarEvent(
        id: _nextId(),
        eventDate: DateTime(year, 8, 15),
        title: 'Independence Day',
        eventType: SchoolCalendarEventType.holiday,
        description: 'Flag hoisting at 8:00 AM, then holiday.',
        createdAt: DateTime(year, 1, 1),
      ),
      SchoolCalendarEvent(
        id: _nextId(),
        eventDate: DateTime(year, 12, 20),
        endDate: DateTime(year, 12, 31),
        title: 'Winter break',
        eventType: SchoolCalendarEventType.holiday,
        description: 'School reopens in January.',
        createdAt: DateTime(year, 1, 1),
      ),
    ]);
  }

  String _nextId() => 'sce-mock-${_seq++}';

  List<SchoolCalendarEvent> list({
    DateTime? from,
    DateTime? to,
    SchoolCalendarEventType? eventType,
  }) {
    final result = _events.where((event) {
      if (from != null && event.eventDate.isBefore(_dateOnly(from))) {
        return false;
      }
      if (to != null && event.eventDate.isAfter(_dateOnly(to))) return false;
      if (eventType != null && event.eventType != eventType) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return result;
  }

  SchoolCalendarEvent create(CreateSchoolCalendarEventInput input) {
    final event = SchoolCalendarEvent(
      id: _nextId(),
      eventDate: _dateOnly(input.eventDate),
      endDate: input.endDate == null ? null : _dateOnly(input.endDate!),
      title: input.title,
      eventType: input.eventType,
      description: input.description,
      createdAt: DateTime.now(),
    );
    _events.add(event);
    return event;
  }

  bool delete(String id) {
    final before = _events.length;
    _events.removeWhere((event) => event.id == id);
    return _events.length != before;
  }

  /// Test hook — clears all entries (no seed).
  void reset() {
    _events.clear();
    _seq = 0;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

/// Mock [SchoolCalendarRepository] backed by [SchoolCalendarMockStore].
class MockSchoolCalendarRepository implements SchoolCalendarRepository {
  MockSchoolCalendarRepository({SchoolCalendarMockStore? store})
      : _store = store ?? SchoolCalendarMockStore.instance;

  final SchoolCalendarMockStore _store;

  @override
  Future<List<SchoolCalendarEvent>> listEvents({
    required RepositoryQuery query,
    DateTime? from,
    DateTime? to,
    SchoolCalendarEventType? eventType,
  }) async {
    return _store.list(from: from, to: to, eventType: eventType);
  }

  @override
  Future<SchoolCalendarEvent> createEvent({
    required RepositoryQuery query,
    required CreateSchoolCalendarEventInput input,
  }) async {
    return _store.create(input);
  }

  @override
  Future<void> deleteEvent({
    required RepositoryQuery query,
    required String id,
  }) async {
    _store.delete(id);
  }
}
