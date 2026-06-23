import '../../../features/parent/attendance/attendance_models.dart';
import '../../../features/parent/timetable/timetable_models.dart';
import '../../../features/student_app/dashboard/student_dashboard_provider.dart';
import '../../../features/student_app/exams/exam_models.dart';
import '../../../features/student_app/homework/homework_models.dart';
import '../../../features/student_app/notices/notices_models.dart';
import '../../../features/student_app/profile/profile_models.dart';
import '../../../features/student_app/student_requests.dart';
import '../repository_query.dart';

/// Contract for student mobile app data access (mock or API).
abstract class StudentRepository {
  Future<StudentDashboardData> getDashboard({required RepositoryQuery query});
  Future<AttendanceMonthData> getAttendance({
    required RepositoryQuery query,
    required DateTime month,
  });
  Future<List<StudentHomeworkItem>> getHomeworkItems({
    required RepositoryQuery query,
  });
  Future<StudentExamsData> getExams({required RepositoryQuery query});
  Future<ParentTimetableData> getTimetable({required RepositoryQuery query});
  Future<List<StudentNotice>> getNotices({required RepositoryQuery query});
  Future<StudentProfileData> getProfile({required RepositoryQuery query});

  Future<StudentHomeworkItem> submitHomework({
    required RepositoryQuery query,
    required StudentHomeworkSubmitRequest request,
  });
}
