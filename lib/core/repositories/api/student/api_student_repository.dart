import '../../../../features/parent/attendance/attendance_models.dart';
import '../../../../features/parent/timetable/timetable_models.dart';
import '../../../../features/student/dashboard/student_dashboard_provider.dart';
import '../../../../features/student/exams/exam_models.dart';
import '../../../../features/student/homework/homework_models.dart';
import '../../../../features/student/notices/notices_models.dart';
import '../../../../features/student/profile/profile_models.dart';
import '../../interfaces/student_repository.dart';
import '../../repository_query.dart';
import '../api_exception.dart';

/// API implementation of [StudentRepository] — enabled via [studentApiEnabledProvider].
class ApiStudentRepository implements StudentRepository {
  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApiStudentRepository', method);
  }

  @override
  Future<StudentDashboardData> getDashboard({required RepositoryQuery query}) async =>
      _notConnected('getDashboard');

  @override
  Future<AttendanceMonthData> getAttendance({
    required RepositoryQuery query,
    required DateTime month,
  }) async =>
      _notConnected('getAttendance');

  @override
  Future<List<StudentHomeworkItem>> getHomeworkItems({
    required RepositoryQuery query,
  }) async =>
      _notConnected('getHomeworkItems');

  @override
  Future<StudentExamsData> getExams({required RepositoryQuery query}) async =>
      _notConnected('getExams');

  @override
  Future<ParentTimetableData> getTimetable({required RepositoryQuery query}) async =>
      _notConnected('getTimetable');

  @override
  Future<List<StudentNotice>> getNotices({required RepositoryQuery query}) async =>
      _notConnected('getNotices');

  @override
  Future<StudentProfileData> getProfile({required RepositoryQuery query}) async =>
      _notConnected('getProfile');
}
