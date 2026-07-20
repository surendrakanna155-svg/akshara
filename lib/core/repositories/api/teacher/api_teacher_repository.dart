import '../../../../features/teacher/attendance/attendance_models.dart';
import '../../../../features/teacher/attendance/my_attendance_models.dart';
import '../../../../features/teacher/dashboard/teacher_dashboard_provider.dart';
import '../../../../features/teacher/exams/exam_models.dart';
import '../../../../features/teacher/homework/homework_models.dart';
import '../../../../features/teacher/leave/leave_models.dart';
import '../../../../features/teacher/messages/message_models.dart';
import '../../../../features/teacher/teacher_requests.dart';
import '../../../../features/teacher/timetable/timetable_models.dart';
import '../../interfaces/teacher_repository.dart';
import '../../../communication/parent_communication_governance.dart';
import '../../../communication/parent_communication_models.dart';
import '../../repository_query.dart';
import 'mapper/teacher_mapper.dart';
import 'remote/teacher_remote_datasource.dart';

/// API implementation of [TeacherRepository] — enabled via [teacherApiEnabledProvider].
class ApiTeacherRepository implements TeacherRepository {
  ApiTeacherRepository({
    required TeacherRemoteDataSource remote,
    TeacherMapper mapper = const TeacherMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final TeacherRemoteDataSource _remote;
  final TeacherMapper _mapper;

  @override
  Future<TeacherDashboardData> getDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<List<TeacherAttendanceClass>> getAttendanceClasses({
    required RepositoryQuery query,
    TeacherTeachingContext? teachingContext,
  }) async {
    // Server scopes attendance classes to the class teacher.
    final dto = await _remote.fetchAttendanceClasses(query: query);
    return _mapper.toAttendanceClasses(dto);
  }

  @override
  Future<Map<String, List<TeacherAttendanceStudent>>>
      getAttendanceStudentsByClass({required RepositoryQuery query}) async {
    final dto = await _remote.fetchAttendanceStudentsByClass(query: query);
    return _mapper.toAttendanceStudentsByClass(dto);
  }

  @override
  Future<List<TeacherHomeworkAssignment>> getHomeworkAssignments({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchHomeworkAssignments(query: query);
    return _mapper.toHomeworkAssignments(dto);
  }

  @override
  Future<List<TeacherUpcomingExam>> getUpcomingExams({
    required RepositoryQuery query,
    TeacherTeachingContext? teachingContext,
  }) async {
    // Scoping to the teacher's assignments is enforced server-side.
    final dto = await _remote.fetchUpcomingExams(query: query);
    return _mapper.toUpcomingExams(dto);
  }

  @override
  Future<List<TeacherExamSessionOption>> getMarksEntryExams({
    required RepositoryQuery query,
    TeacherTeachingContext? teachingContext,
  }) async {
    // Scoping to the teacher's assignments is enforced server-side.
    final dto = await _remote.fetchMarksEntryExams(query: query);
    return _mapper.toMarksEntryExams(dto);
  }

  @override
  Future<List<ExamMarkEntry>> getExamMarks({
    required RepositoryQuery query,
    String? examId,
  }) async {
    final dto = await _remote.fetchExamMarks(query: query, examId: examId);
    return _mapper.toExamMarks(dto);
  }

  @override
  Future<TeacherTimetableData> getTimetable({required RepositoryQuery query}) async {
    final dto = await _remote.fetchTimetable(query: query);
    return _mapper.toTimetable(dto);
  }

  @override
  Future<List<TeacherLeaveRequest>> getLeaveHistory({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.fetchLeaveHistory(query: query);
    return _mapper.toLeaveHistory(dto);
  }

  @override
  Future<LeaveBalance> getLeaveBalance({required RepositoryQuery query}) async {
    final dto = await _remote.fetchLeaveBalance(query: query);
    return _mapper.toLeaveBalance(dto);
  }

  @override
  Future<List<MessageThread>> getMessageThreads({required RepositoryQuery query}) async {
    final dto = await _remote.fetchMessageThreads(query: query);
    return _mapper.toMessageThreads(dto);
  }

  @override
  Future<TeacherAttendanceDraftResult> saveAttendanceDraft({
    required RepositoryQuery query,
    required TeacherAttendanceDraftRequest request,
  }) async {
    final dto = await _remote.saveAttendanceDraft(query: query, request: request);
    return _mapper.toAttendanceDraftResult(dto);
  }

  @override
  Future<TeacherAttendanceSubmitResult> submitClassAttendance({
    required RepositoryQuery query,
    required TeacherAttendanceSubmitRequest request,
  }) async {
    final dto = await _remote.submitClassAttendance(query: query, request: request);
    return _mapper.toAttendanceSubmitResult(dto);
  }

  @override
  Future<TeacherHomeworkReviewResult> reviewHomeworkSubmission({
    required RepositoryQuery query,
    required TeacherHomeworkReviewRequest request,
  }) async {
    final dto = await _remote.reviewHomeworkSubmission(query: query, request: request);
    return _mapper.toHomeworkReviewResult(dto);
  }

  @override
  Future<ExamMarkEntry> updateExamMark({
    required RepositoryQuery query,
    required TeacherExamMarkUpdateRequest request,
  }) async {
    final dto = await _remote.updateExamMark(query: query, request: request);
    return _mapper.toExamMark(dto);
  }

  @override
  Future<TeacherExamProcessResultsResult> processExamResults({
    required RepositoryQuery query,
    required TeacherExamProcessResultsRequest request,
  }) async {
    final dto = await _remote.processExamResults(query: query, request: request);
    return _mapper.toExamProcessResultsResult(dto);
  }

  @override
  Future<TeacherExamPublishResult> publishExamResults({
    required RepositoryQuery query,
    required TeacherExamPublishRequest request,
  }) async {
    final dto = await _remote.publishExamResults(query: query, request: request);
    return _mapper.toExamPublishResult(dto);
  }

  @override
  Future<ParentCommunicationSendResult> sendParentCommunication({
    required RepositoryQuery query,
    required TeacherParentCommunicationSendRequest request,
    required TeacherTeachingContext teachingContext,
  }) async {
    final dto = await _remote.sendParentCommunication(
      query: query,
      request: request,
      teachingContext: teachingContext,
    );
    return _mapper.toParentCommunicationSendResult(dto);
  }

  @override
  Future<SubjectTeacherConcernFlagResult> flagSubjectConcern({
    required RepositoryQuery query,
    required TeacherSubjectConcernFlagRequest request,
    required TeacherTeachingContext teachingContext,
  }) async {
    final dto = await _remote.flagSubjectConcern(
      query: query,
      request: request,
      teachingContext: teachingContext,
    );
    return _mapper.toSubjectConcernFlagResult(dto);
  }

  @override
  Future<List<SubjectTeacherConcern>> listPendingConcerns({
    required RepositoryQuery query,
    required TeacherTeachingContext teachingContext,
  }) async {
    final dto = await _remote.listPendingConcerns(
      query: query,
      teachingContext: teachingContext,
    );
    return _mapper.toSubjectConcerns(dto);
  }

  @override
  Future<List<ParentCommunicationRecord>> listParentCommunications({
    required RepositoryQuery query,
    required String sisStudentId,
  }) async {
    final items = await _remote.listParentCommunications(
      query: query,
      sisStudentId: sisStudentId,
    );
    return _mapper.toParentCommunicationTimeline(items);
  }

  @override
  Future<SubjectTeacherConcern> dismissSubjectConcern({
    required RepositoryQuery query,
    required String concernId,
    required TeacherTeachingContext teachingContext,
    String? note,
  }) async {
    final dto = await _remote.dismissSubjectConcern(
      query: query,
      concernId: concernId,
      teachingContext: teachingContext,
      note: note,
    );
    return _mapper.toSubjectConcern(dto);
  }

  @override
  Future<TeacherLeaveRequest> submitLeaveRequest({
    required RepositoryQuery query,
    required TeacherLeaveSubmitRequest request,
  }) async {
    final dto = await _remote.submitLeaveRequest(query: query, request: request);
    return _mapper.toLeaveRequest(dto);
  }

  @override
  Future<MessageThread> sendMessage({
    required RepositoryQuery query,
    required TeacherMessageSendRequest request,
  }) async {
    final dto = await _remote.sendMessage(query: query, request: request);
    return _mapper.toMessageThread(dto);
  }

  @override
  Future<TeacherHomeworkAssignment> createHomework({
    required RepositoryQuery query,
    required TeacherHomeworkCreateRequest request,
  }) async {
    return _remote.createHomework(query: query, request: request);
  }

  @override
  Future<TeacherHomeworkAssignment> createHomeworkFile({
    required RepositoryQuery query,
    required TeacherHomeworkCreateRequest request,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    // PRA-P1-30: presign → PUT bytes → create with the real storage_path.
    final presign = await _remote.presignHomeworkAttachment(
      query: query,
      fileName: fileName,
    );
    await _remote.putSignedUpload(
      signedUrl: presign.signedUrl,
      bytes: bytes,
      contentType: contentType,
    );
    return _remote.createHomework(
      query: query,
      request: TeacherHomeworkCreateRequest(
        classLabel: request.classLabel,
        subject: request.subject,
        title: request.title,
        dueDate: request.dueDate,
        dueLabel: request.dueLabel,
        studentName: request.studentName,
        classLabels: request.classLabels,
        attachmentName: request.attachmentName,
        attachmentRef: request.attachmentRef,
        attachmentStoragePath: presign.storagePath,
      ),
    );
  }

  @override
  Future<List<HomeworkNonSubmitter>> getHomeworkNonSubmitters({
    required RepositoryQuery query,
    required String homeworkId,
  }) async {
    return _remote.fetchHomeworkNonSubmitters(query: query, homeworkId: homeworkId);
  }

  @override
  Future<HomeworkBulkReviewResult> bulkReviewHomework({
    required RepositoryQuery query,
    required TeacherHomeworkBulkReviewRequest request,
  }) async {
    return _remote.bulkReviewHomework(query: query, request: request);
  }

  @override
  Future<HomeworkNotifyResult> notifyHomeworkNonSubmitters({
    required RepositoryQuery query,
    required String homeworkId,
    String? message,
  }) async {
    return _remote.notifyHomeworkNonSubmitters(
      query: query,
      homeworkId: homeworkId,
      message: message,
    );
  }

  @override
  Future<List<TeacherHomeworkHistoryItem>> getHomeworkHistory({
    required RepositoryQuery query,
    String? fromDate,
    String? toDate,
  }) async {
    return _remote.fetchHomeworkHistory(
      query: query,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  @override
  Future<MyAttendanceHistory> getMyAttendanceHistory({
    required RepositoryQuery query,
    String? month,
  }) async {
    final dto = await _remote.fetchMyAttendanceHistory(query: query, month: month);
    return _mapper.toMyAttendanceHistory(dto);
  }
}
