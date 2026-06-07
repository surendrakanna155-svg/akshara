import '../../../features/teacher/attendance/attendance_models.dart';
import '../../../features/teacher/dashboard/teacher_dashboard_provider.dart';
import '../../../features/teacher/exams/exam_models.dart';
import '../../../features/teacher/homework/homework_models.dart';
import '../../../features/teacher/leave/leave_models.dart';
import '../../../features/teacher/messages/message_models.dart';
import '../../../features/teacher/timetable/timetable_models.dart';
import '../repository_query.dart';

/// Contract for teacher mobile app data access (mock or API).
abstract class TeacherRepository {
  Future<TeacherDashboardData> getDashboard({required RepositoryQuery query});
  Future<List<TeacherAttendanceClass>> getAttendanceClasses({
    required RepositoryQuery query,
  });
  Future<Map<String, List<TeacherAttendanceStudent>>>
      getAttendanceStudentsByClass({required RepositoryQuery query});
  Future<List<TeacherHomeworkAssignment>> getHomeworkAssignments({
    required RepositoryQuery query,
  });
  Future<List<TeacherUpcomingExam>> getUpcomingExams({
    required RepositoryQuery query,
  });
  Future<List<ExamMarkEntry>> getExamMarks({required RepositoryQuery query});
  Future<TeacherTimetableData> getTimetable({required RepositoryQuery query});
  Future<List<TeacherLeaveRequest>> getLeaveHistory({
    required RepositoryQuery query,
  });
  Future<LeaveBalance> getLeaveBalance({required RepositoryQuery query});
  Future<List<MessageThread>> getMessageThreads({required RepositoryQuery query});
}
