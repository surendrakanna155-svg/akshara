import '../../../features/teacher/attendance/attendance_models.dart';
import '../../../features/teacher/dashboard/teacher_dashboard_provider.dart';
import '../../../features/teacher/exams/exam_models.dart';
import '../../../features/teacher/homework/homework_models.dart';
import '../../../features/teacher/leave/leave_models.dart';
import '../../../features/teacher/messages/message_models.dart';
import '../../../features/teacher/teacher_requests.dart';
import '../../../features/teacher/timetable/timetable_models.dart';
import '../../communication/parent_communication_governance.dart';
import '../../communication/parent_communication_models.dart';
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

  Future<TeacherAttendanceDraftResult> saveAttendanceDraft({
    required RepositoryQuery query,
    required TeacherAttendanceDraftRequest request,
  });

  Future<TeacherAttendanceSubmitResult> submitClassAttendance({
    required RepositoryQuery query,
    required TeacherAttendanceSubmitRequest request,
  });

  Future<TeacherHomeworkReviewResult> reviewHomeworkSubmission({
    required RepositoryQuery query,
    required TeacherHomeworkReviewRequest request,
  });

  Future<ExamMarkEntry> updateExamMark({
    required RepositoryQuery query,
    required TeacherExamMarkUpdateRequest request,
  });

  Future<TeacherExamPublishResult> publishExamResults({
    required RepositoryQuery query,
    required TeacherExamPublishRequest request,
  });

  Future<ParentCommunicationSendResult> sendParentCommunication({
    required RepositoryQuery query,
    required TeacherParentCommunicationSendRequest request,
    required TeacherTeachingContext teachingContext,
  });

  Future<SubjectTeacherConcernFlagResult> flagSubjectConcern({
    required RepositoryQuery query,
    required TeacherSubjectConcernFlagRequest request,
    required TeacherTeachingContext teachingContext,
  });

  Future<List<SubjectTeacherConcern>> listPendingConcerns({
    required RepositoryQuery query,
    required TeacherTeachingContext teachingContext,
  });

  Future<SubjectTeacherConcern> dismissSubjectConcern({
    required RepositoryQuery query,
    required String concernId,
    required TeacherTeachingContext teachingContext,
    String? note,
  });

  Future<TeacherLeaveRequest> submitLeaveRequest({
    required RepositoryQuery query,
    required TeacherLeaveSubmitRequest request,
  });

  Future<MessageThread> sendMessage({
    required RepositoryQuery query,
    required TeacherMessageSendRequest request,
  });
}
