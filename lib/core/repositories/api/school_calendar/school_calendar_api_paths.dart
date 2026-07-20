/// REST paths for the school holiday/event calendar (PRA-P1-17).
abstract final class SchoolCalendarApiPaths {
  static const String base = '/school-calendar';

  static String event(String id) => '$base/$id';
}
