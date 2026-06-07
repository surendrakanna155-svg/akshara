/// REST paths for the Alumni API module.
abstract final class AlumniApiPaths {
  static const String base = '/alumni';

  static const String dashboard = '$base/dashboard';
  static const String registry = '$base/registry';
  static const String events = '$base/events';
  static const String donations = '$base/donations';
  static const String campaigns = '$base/campaigns';
  static const String mentorship = '$base/mentorship';
  static const String reports = '$base/reports';
  static const String settings = '$base/settings';

  static String alumniDetail(String alumniId) => '$base/registry/$alumniId';
}
