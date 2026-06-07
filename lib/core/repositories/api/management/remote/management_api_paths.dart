/// REST paths for the Management API module.
abstract final class ManagementApiPaths {
  static const String base = '/management';

  static const String dashboard = '$base/dashboard';
  static const String analytics = '$base/analytics';
  static const String admissionsFunnel = '$base/admissions-funnel';
  static const String financialHealth = '$base/financial-health';
  static const String academicHealth = '$base/academic-health';
  static const String schoolPerformance = '$base/school-performance';
  static const String tasks = '$base/tasks';
  static const String settings = '$base/settings';
}
