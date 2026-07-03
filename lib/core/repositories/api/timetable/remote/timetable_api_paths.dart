abstract final class TimetableApiPaths {
  static const String timetables = '/academic/timetables';
  static const String summary = '/academic/timetables/summary';
  static const String workload = '/academic/timetables/workload';
  static const String conflicts = '/academic/timetables/conflicts';
  static const String generate = '/academic/timetables/generate';
  static const String validate = '/academic/timetables/validate';
  static const String movePeriod = '/academic/timetables/periods/move';
  static const String reassignPeriodTeacher =
      '/academic/timetables/periods/reassign-teacher';
  static const String substitutions = '/academic/timetables/substitutions';
  static String detail(String id) => '$timetables/$id';
  static String publish(String id) => '$timetables/$id/publish';
  static String substitution(String id) => '$substitutions/$id';
}
