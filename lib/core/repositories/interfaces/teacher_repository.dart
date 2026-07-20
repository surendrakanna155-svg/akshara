import '../../../features/teacher/attendance/attendance_models.dart';
import '../../../features/teacher/attendance/my_attendance_models.dart';
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
    TeacherTeachingContext? teachingContext,
  });
  Future<Map<String, List<TeacherAttendanceStudent>>>
      getAttendanceStudentsByClass({required RepositoryQuery query});
  Future<List<TeacherHomeworkAssignment>> getHomeworkAssignments({
    required RepositoryQuery query,
  });
  Future<List<TeacherUpcomingExam>> getUpcomingExams({
    required RepositoryQuery query,
    TeacherTeachingContext? teachingContext,
  });
  Future<List<TeacherExamSessionOption>> getMarksEntryExams({
    required RepositoryQuery query,
    TeacherTeachingContext? teachingContext,
  });
  Future<List<ExamMarkEntry>> getExamMarks({
    required RepositoryQuery query,
    String? examId,
  });
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

  Future<TeacherExamProcessResultsResult> processExamResults({
    required RepositoryQuery query,
    required TeacherExamProcessResultsRequest request,
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

  /// PRA-P0-17: live teacher→parent communication timeline for a student
  /// (newest first), replacing the never-populated in-memory store.
  Future<List<ParentCommunicationRecord>> listParentCommunications({
    required RepositoryQuery query,
    required String sisStudentId,
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

  Future<TeacherHomeworkAssignment> createHomework({
    required RepositoryQuery query,
    required TeacherHomeworkCreateRequest request,
  });

  /// PRA-P1-30 — create homework with a REAL worksheet attachment: presign → PUT
  /// [bytes] → create with the resulting storage_path. Replaces the old label-only
  /// attachment (which stored no file). The API impl performs the upload; the mock
  /// persists metadata.
  Future<TeacherHomeworkAssignment> createHomeworkFile({
    required RepositoryQuery query,
    required TeacherHomeworkCreateRequest request,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  });

  /// HWK-2 — students the assignment was delivered to who have NOT submitted.
  Future<List<HomeworkNonSubmitter>> getHomeworkNonSubmitters({
    required RepositoryQuery query,
    required String homeworkId,
  });

  /// HWK-6 — bulk mark submissions reviewed (partial success).
  Future<HomeworkBulkReviewResult> bulkReviewHomework({
    required RepositoryQuery query,
    required TeacherHomeworkBulkReviewRequest request,
  });

  /// HWK-D1 — manual parent no-submit nudge for an assignment.
  Future<HomeworkNotifyResult> notifyHomeworkNonSubmitters({
    required RepositoryQuery query,
    required String homeworkId,
    String? message,
  });

  /// HWK-5 — the teacher's homework history, optionally filtered to a due-date
  /// range (inclusive ISO `YYYY-MM-DD`).
  Future<List<TeacherHomeworkHistoryItem>> getHomeworkHistory({
    required RepositoryQuery query,
    String? fromDate,
    String? toDate,
  });

  /// TCH-9 — the caller's OWN staff attendance history for a month (defaults to
  /// the current month when [month] is null). READ-ONLY, self-scoped: the server
  /// derives it from the append-only check-in ledger and never returns another
  /// user's rows.
  Future<MyAttendanceHistory> getMyAttendanceHistory({
    required RepositoryQuery query,
    String? month,
  });
}
