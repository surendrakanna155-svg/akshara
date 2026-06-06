import '../../../features/sis/sis_models.dart';

/// Contract for student SIS data access (mock or API).
abstract class SisRepository {
  SisDashboardData getDashboard();
  List<SisStudent> getStudents();
  List<String> getClassOptions();
  List<String> getSectionOptions();
  List<String> getAcademicYearOptions();
}
