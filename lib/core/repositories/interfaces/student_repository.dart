import '../../../features/parent/attendance/attendance_models.dart';
import '../../../features/parent/timetable/timetable_models.dart';
import '../../../features/student/dashboard/student_dashboard_provider.dart';
import '../../../features/student/exams/exam_models.dart';
import '../../../features/student/homework/homework_models.dart';
import '../../../features/student/notices/notices_models.dart';
import '../../../features/student/profile/profile_models.dart';
import '../../../features/student/student_requests.dart';
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
