/// REST paths for the Student mobile API module.
abstract final class StudentApiPaths {
  static const String base = '/student';

  static const String dashboard = '$base/dashboard';
  static const String attendance = '$base/attendance';
  static const String homework = '$base/homework';
  static const String exams = '$base/exams';
  static const String timetable = '$base/timetable';
  static const String notices = '$base/notices';
  static const String profile = '$base/profile';
  static const String homeworkSubmit = '$base/homework/submit';
}
