import '../../../../features/teacher/attendance/attendance_models.dart';
import '../../../../features/teacher/dashboard/teacher_dashboard_provider.dart';
import '../../../../features/teacher/exams/exam_models.dart';
import '../../../../features/teacher/homework/homework_models.dart';
import '../../../../features/teacher/leave/leave_models.dart';
import '../../../../features/teacher/messages/message_models.dart';
import '../../../../features/teacher/timetable/timetable_models.dart';
import '../../interfaces/teacher_repository.dart';
import '../../repository_query.dart';
import '../api_exception.dart';

/// API implementation of [TeacherRepository] — enabled via [teacherApiEnabledProvider].
class ApiTeacherRepository implements TeacherRepository {
  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApiTeacherRepository', method);
  }

  @override
  Future<TeacherDashboardData> getDashboard({required RepositoryQuery query}) async =>
      _notConnected('getDashboard');

  @override
  Future<List<TeacherAttendanceClass>> getAttendanceClasses({
    required RepositoryQuery query,
  }) async =>
      _notConnected('getAttendanceClasses');

  @override
  Future<Map<String, List<TeacherAttendanceStudent>>>
      getAttendanceStudentsByClass({required RepositoryQuery query}) async =>
      _notConnected('getAttendanceStudentsByClass');

  @override
  Future<List<TeacherHomeworkAssignment>> getHomeworkAssignments({
    required RepositoryQuery query,
  }) async =>
      _notConnected('getHomeworkAssignments');

  @override
  Future<List<TeacherUpcomingExam>> getUpcomingExams({
    required RepositoryQuery query,
  }) async =>
      _notConnected('getUpcomingExams');

  @override
  Future<List<ExamMarkEntry>> getExamMarks({required RepositoryQuery query}) async =>
      _notConnected('getExamMarks');

  @override
  Future<TeacherTimetableData> getTimetable({required RepositoryQuery query}) async =>
      _notConnected('getTimetable');

  @override
  Future<List<TeacherLeaveRequest>> getLeaveHistory({
    required RepositoryQuery query,
  }) async =>
      _notConnected('getLeaveHistory');

  @override
  Future<LeaveBalance> getLeaveBalance({required RepositoryQuery query}) async =>
      _notConnected('getLeaveBalance');

  @override
  Future<List<MessageThread>> getMessageThreads({required RepositoryQuery query}) async =>
      _notConnected('getMessageThreads');
}
