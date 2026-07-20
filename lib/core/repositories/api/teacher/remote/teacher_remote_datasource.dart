import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../../../../../features/teacher/attendance/attendance_models.dart';
import '../../../../../features/teacher/homework/homework_models.dart';
import '../../../../../features/teacher/teacher_requests.dart';
import '../../../../communication/parent_communication_governance.dart';
import '../../../../reliability/model/mutation_outcome.dart';
import '../../../../reliability/policy/operation_policy_registry.dart';
import '../../../../reliability/reliable_datasource_write.dart';
import '../../../../reliability/reliable_writer.dart';
import '../dto/teacher_responses_dto.dart';
import '../dto/teacher_write_request_dto.dart';
import 'teacher_api_paths.dart';

/// Dio-backed remote data source for Teacher mobile APIs.
///
/// Pilot-critical writes (attendance draft/submit, leave) route through the
/// Data Reliability Platform's [ReliableWriter] when one is injected: every such
/// write is queued offline, replayed exactly-once on reconnect, and returns an
/// optimistic result while pending. When no writer is supplied (e.g. legacy unit
/// tests) the methods fall back to a direct Dio call — identical online
/// behaviour, no reliability.
class TeacherRemoteDataSource {
  TeacherRemoteDataSource(this._dio, {ReliableWriter? reliableWriter})
      : _reliable = reliableWriter;

  final Dio _dio;
  final ReliableWriter? _reliable;

  Future<TeacherDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return TeacherDashboardDto.fromJson(_responseMap(response));
  }

  Future<TeacherAttendanceClassesResponseDto> fetchAttendanceClasses({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.attendanceClasses,
      queryParameters: _queryParams(query),
    );
    return TeacherAttendanceClassesResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherAttendanceStudentsResponseDto> fetchAttendanceStudentsByClass({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.attendanceStudents,
      queryParameters: _queryParams(query),
    );
    return TeacherAttendanceStudentsResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherHomeworkResponseDto> fetchHomeworkAssignments({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.homework,
      queryParameters: _queryParams(query),
    );
    return TeacherHomeworkResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherUpcomingExamsResponseDto> fetchUpcomingExams({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.examsUpcoming,
      queryParameters: _queryParams(query),
    );
    return TeacherUpcomingExamsResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherMarksEntryExamsResponseDto> fetchMarksEntryExams({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.examsMarksEntry,
      queryParameters: _queryParams(query),
    );
    return TeacherMarksEntryExamsResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherExamMarksResponseDto> fetchExamMarks({
    required RepositoryQuery query,
    String? examId,
  }) async {
    final params = _queryParams(query);
    if (examId != null) params['examId'] = examId;
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.examsMarks,
      queryParameters: params,
    );
    return TeacherExamMarksResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherTimetableResponseDto> fetchTimetable({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.timetable,
      queryParameters: _queryParams(query),
    );
    return TeacherTimetableResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherLeaveResponseDto> fetchLeaveHistory({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.leave,
      queryParameters: _queryParams(query),
    );
    return TeacherLeaveResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherLeaveBalanceResponseDto> fetchLeaveBalance({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.leaveBalance,
      queryParameters: _queryParams(query),
    );
    return TeacherLeaveBalanceResponseDto.fromJson(_responseMap(response));
  }

  Future<TeacherMessagesResponseDto> fetchMessageThreads({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.messages,
      queryParameters: _queryParams(query),
    );
    return TeacherMessagesResponseDto.fromJson(_responseMap(response));
  }

  // TCH-9 — the caller's OWN staff attendance history (self-scoped, read-only).
  Future<MyAttendanceHistoryDto> fetchMyAttendanceHistory({
    required RepositoryQuery query,
    String? month,
  }) async {
    final params = _queryParams(query);
    if (month != null && month.isNotEmpty) params['month'] = month;
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.myAttendanceHistory,
      queryParameters: params,
    );
    return MyAttendanceHistoryDto.fromJson(_responseMap(response));
  }

  Future<TeacherAttendanceDraftResponseDto> saveAttendanceDraft({
    required RepositoryQuery query,
    required TeacherAttendanceDraftRequest request,
  }) async {
    final Map<String, dynamic> data = await _reliableWrite(
      type: OperationTypes.markAttendance,
      method: 'POST',
      path: TeacherApiPaths.attendanceDraft,
      query: query,
      body: TeacherAttendanceDraftRequestDto.fromDomain(request).toJson(),
      entityRef: 'attendance:${request.classId}',
      optimistic: () => <String, dynamic>{
        'classId': request.classId,
        'savedAtLabel': 'Pending sync',
        'markedCount': request.entries.length,
      },
    );
    return TeacherAttendanceDraftResponseDto.fromJson(data);
  }

  Future<TeacherAttendanceSubmitResponseDto> submitClassAttendance({
    required RepositoryQuery query,
    required TeacherAttendanceSubmitRequest request,
  }) async {
    final Map<String, dynamic> data = await _reliableWrite(
      type: OperationTypes.submitAttendance,
      method: 'POST',
      path: TeacherApiPaths.attendanceSubmit,
      query: query,
      body: TeacherAttendanceSubmitRequestDto.fromDomain(request).toJson(),
      entityRef: 'attendance:${request.classId}',
      optimistic: () => <String, dynamic>{
        'classId': request.classId,
        'submittedAtLabel': 'Pending sync',
        'presentCount': request.entries
            .where((e) => e.mark == StudentAttendanceMark.present)
            .length,
        'absentCount': request.entries
            .where((e) => e.mark == StudentAttendanceMark.absent)
            .length,
        'lateCount': request.entries
            .where((e) => e.mark == StudentAttendanceMark.late)
            .length,
        'halfDayCount': request.entries
            .where((e) => e.mark == StudentAttendanceMark.halfDay)
            .length,
        'excusedCount': request.entries
            .where((e) => e.mark == StudentAttendanceMark.excused)
            .length,
      },
    );
    return TeacherAttendanceSubmitResponseDto.fromJson(data);
  }

  Future<TeacherHomeworkReviewResponseDto> reviewHomeworkSubmission({
    required RepositoryQuery query,
    required TeacherHomeworkReviewRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TeacherApiPaths.homeworkReview(request.submissionId),
      queryParameters: _queryParams(query),
      data: TeacherHomeworkReviewRequestDto.fromDomain(request).toJson(),
    );
    return TeacherHomeworkReviewResponseDto.fromJson(_requireData(response));
  }

  Future<ExamMarkEntryDto> updateExamMark({
    required RepositoryQuery query,
    required TeacherExamMarkUpdateRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      TeacherApiPaths.examMark(request.markEntryId),
      queryParameters: _queryParams(query),
      data: TeacherExamMarkUpdateRequestDto.fromDomain(request).toJson(),
    );
    return ExamMarkEntryDto.fromJson(_requireData(response));
  }

  Future<Map<String, dynamic>> processExamResults({
    required RepositoryQuery query,
    required TeacherExamProcessResultsRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TeacherApiPaths.examProcess(request.examId),
      queryParameters: _queryParams(query),
    );
    return _requireData(response);
  }

  Future<Map<String, dynamic>> publishExamResults({
    required RepositoryQuery query,
    required TeacherExamPublishRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TeacherApiPaths.examPublish(request.examId),
      queryParameters: _queryParams(query),
    );
    return _requireData(response);
  }

  Future<Map<String, dynamic>> sendParentCommunication({
    required RepositoryQuery query,
    required TeacherParentCommunicationSendRequest request,
    required TeacherTeachingContext teachingContext,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TeacherApiPaths.parentCommunication,
      queryParameters: _queryParams(query),
      data: {
        'sisStudentId': request.sisStudentId,
        'reason': request.reason.name,
        'tone': request.tone.name,
        'channels': request.channels.map((c) => c.name).toList(),
        'teachingRole': teachingContext.commsRole.name,
        if (request.customMessage != null) 'customMessage': request.customMessage,
        'useAi': request.useAi,
        if (request.sourceConcernId != null)
          'sourceConcernId': request.sourceConcernId,
      },
    );
    return _requireData(response);
  }

  Future<Map<String, dynamic>> flagSubjectConcern({
    required RepositoryQuery query,
    required TeacherSubjectConcernFlagRequest request,
    required TeacherTeachingContext teachingContext,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TeacherApiPaths.parentCommunicationConcerns,
      queryParameters: _queryParams(query),
      data: {
        'sisStudentId': request.sisStudentId,
        'category': request.category.name,
        'observation': request.observation,
        'subject': teachingContext.primarySubject,
      },
    );
    return _requireData(response);
  }

  // PRA-P0-17 (S0/T2-F): live teacher→parent communication timeline for a student.
  Future<List<Map<String, dynamic>>> listParentCommunications({
    required RepositoryQuery query,
    required String sisStudentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.parentCommunication,
      queryParameters: {
        ..._queryParams(query),
        'sisStudentId': sisStudentId,
      },
    );
    final data = _requireData(response);
    final items = data['items'] as List<dynamic>? ?? const [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) item,
    ];
  }

  Future<List<Map<String, dynamic>>> listPendingConcerns({
    required RepositoryQuery query,
    required TeacherTeachingContext teachingContext,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.parentCommunicationConcerns,
      queryParameters: {
        ..._queryParams(query),
        'classLabel': teachingContext.classTeacherClassLabel ?? '',
      },
    );
    final data = _requireData(response);
    final items = data['items'] as List<dynamic>? ?? const [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) item,
    ];
  }

  Future<Map<String, dynamic>> dismissSubjectConcern({
    required RepositoryQuery query,
    required String concernId,
    required TeacherTeachingContext teachingContext,
    String? note,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${TeacherApiPaths.parentCommunicationConcerns}/$concernId/dismiss',
      queryParameters: _queryParams(query),
      data: {if (note != null) 'note': note},
    );
    return _requireData(response);
  }

  Future<TeacherLeaveRequestDto> submitLeaveRequest({
    required RepositoryQuery query,
    required TeacherLeaveSubmitRequest request,
  }) async {
    final Map<String, dynamic> data = await _reliableWrite(
      type: OperationTypes.applyLeave,
      method: 'POST',
      path: TeacherApiPaths.leave,
      query: query,
      body: TeacherLeaveSubmitRequestDto.fromDomain(request).toJson(),
      entityRef: 'leave:teacher',
      optimistic: () => <String, dynamic>{
        'id': 'pending-${request.fromDateLabel}-${request.toDateLabel}',
        'typeLabel': request.typeLabel,
        'fromDateLabel': request.fromDateLabel,
        'toDateLabel': request.toDateLabel,
        'reason': request.reason,
        'status': 'pending',
        'timeline': const <dynamic>[],
      },
    );
    return TeacherLeaveRequestDto.fromJson(data);
  }

  Future<MessageThreadDto> sendMessage({
    required RepositoryQuery query,
    required TeacherMessageSendRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TeacherApiPaths.messages,
      queryParameters: _queryParams(query),
      data: TeacherMessageSendRequestDto.fromDomain(request).toJson(),
    );
    return MessageThreadDto.fromJson(_requireData(response));
  }

  /// PRA-P1-30 — presign a real worksheet attachment upload, returning the signed
  /// URL and the storage path to confirm with on create.
  Future<({String signedUrl, String storagePath})> presignHomeworkAttachment({
    required RepositoryQuery query,
    required String fileName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TeacherApiPaths.homeworkAttachmentPresign,
      queryParameters: _queryParams(query),
      data: {'file_name': fileName},
    );
    final data = _requireData(response);
    return (
      signedUrl: data['signedUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
    );
  }

  /// PUT file bytes to the Supabase signed upload URL (separate host from API).
  Future<void> putSignedUpload({
    required String signedUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    final uploadClient = Dio(
      BaseOptions(
        headers: {'Content-Type': contentType},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final response = await uploadClient.put<List<int>>(
      signedUrl,
      data: bytes,
      options: Options(responseType: ResponseType.bytes),
    );
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Upload failed (${response.statusCode})',
      );
    }
  }

  Future<TeacherHomeworkAssignment> createHomework({
    required RepositoryQuery query,
    required TeacherHomeworkCreateRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TeacherApiPaths.homeworkCreate,
      queryParameters: _queryParams(query),
      data: TeacherHomeworkCreateRequestDto.fromDomain(request).toJson(),
    );
    final data = _requireData(response);
    // Response data: { id, title, classLabel, subject, dueLabel, deliveredCount }.
    // TeacherHomeworkAssignment carries no subject/deliveredCount; a freshly
    // created assignment has no submissions yet, so default to empty.
    return TeacherHomeworkAssignment(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? request.title).toString(),
      classLabel: (data['classLabel'] ?? request.classLabel).toString(),
      dueLabel: (data['dueLabel'] ?? request.dueLabel).toString(),
      submissions: const [],
    );
  }

  // HWK-2 — not-submitted list. Response: { homeworkId, notSubmittedCount,
  // items: [{ studentId, name }] }.
  Future<List<HomeworkNonSubmitter>> fetchHomeworkNonSubmitters({
    required RepositoryQuery query,
    required String homeworkId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.homeworkNonSubmitters(homeworkId),
      queryParameters: _queryParams(query),
    );
    final data = _requireData(response);
    final items = (data['items'] as List<dynamic>? ?? const []);
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HomeworkNonSubmitter(
            studentId: (item['studentId'] ?? '').toString(),
            name: (item['name'] ?? 'Student').toString(),
          ),
    ];
  }

  // HWK-6 — bulk mark-reviewed. Response: { reviewed, skipped, reviewedIds }.
  Future<HomeworkBulkReviewResult> bulkReviewHomework({
    required RepositoryQuery query,
    required TeacherHomeworkBulkReviewRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TeacherApiPaths.homeworkBulkReview,
      queryParameters: _queryParams(query),
      data: {
        'homework_id': request.homeworkId,
        if (request.submissionIds.isNotEmpty)
          'submission_ids': request.submissionIds,
        'grade': request.grade,
        'comment': request.comment,
      },
    );
    final data = _requireData(response);
    return HomeworkBulkReviewResult(
      reviewed: (data['reviewed'] as num?)?.toInt() ?? 0,
      skipped: (data['skipped'] as num?)?.toInt() ?? 0,
      reviewedIds: [
        for (final id in (data['reviewedIds'] as List<dynamic>? ?? const []))
          id.toString(),
      ],
    );
  }

  // HWK-D1 — manual parent no-submit nudge. Response: { studentsPending,
  // notificationsQueued }.
  Future<HomeworkNotifyResult> notifyHomeworkNonSubmitters({
    required RepositoryQuery query,
    required String homeworkId,
    String? message,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      TeacherApiPaths.homeworkNotifyNonSubmitters(homeworkId),
      queryParameters: _queryParams(query),
      data: {
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
      },
    );
    final data = _requireData(response);
    return HomeworkNotifyResult(
      studentsPending: (data['studentsPending'] as num?)?.toInt() ?? 0,
      notificationsQueued: (data['notificationsQueued'] as num?)?.toInt() ?? 0,
    );
  }

  // HWK-5 — homework history (optional ISO date range). Response:
  // { items: [{ id, title, classLabel, subject, dueLabel, dueDate,
  //   submittedCount, totalCount }], pagination }.
  Future<List<TeacherHomeworkHistoryItem>> fetchHomeworkHistory({
    required RepositoryQuery query,
    String? fromDate,
    String? toDate,
  }) async {
    final params = _queryParams(query);
    if (fromDate != null && fromDate.isNotEmpty) params['from'] = fromDate;
    if (toDate != null && toDate.isNotEmpty) params['to'] = toDate;
    final response = await _dio.get<Map<String, dynamic>>(
      TeacherApiPaths.homeworkHistory,
      queryParameters: params,
    );
    final data = _requireData(response);
    final items = (data['items'] as List<dynamic>? ?? const []);
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TeacherHomeworkHistoryItem(
            id: (item['id'] ?? '').toString(),
            title: (item['title'] ?? '').toString(),
            classLabel: (item['classLabel'] ?? '').toString(),
            subject: (item['subject'] ?? '').toString(),
            dueLabel: (item['dueLabel'] ?? '').toString(),
            dueDate: item['dueDate'] as String?,
            submittedCount: (item['submittedCount'] as num?)?.toInt() ?? 0,
            totalCount: (item['totalCount'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  /// Routes a pilot-critical write through the reliability platform when a
  /// [ReliableWriter] is available; otherwise performs a direct Dio call
  /// (legacy/online-only). Returns the response `data` map the caller parses:
  /// the server row when confirmed, or [optimistic]'s projection when the write
  /// was queued offline (the Sync Center surfaces it until confirmed).
  Future<Map<String, dynamic>> _reliableWrite({
    required String type,
    required String method,
    required String path,
    required RepositoryQuery query,
    required Map<String, dynamic> body,
    required Map<String, dynamic> Function() optimistic,
    String? entityRef,
  }) async {
    final ReliableWriter? reliable = _reliable;
    if (reliable == null) {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: body,
        queryParameters: _queryParams(query),
        options: Options(method: method),
      );
      return _requireData(response);
    }
    final MutationOutcome outcome = await reliable.runWrite(
      type: type,
      method: method,
      path: path,
      body: body,
      scope: _queryParams(query),
      entityRef: entityRef,
    );
    return resolveWriteOutcome(outcome, optimistic: optimistic).data;
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
    };
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(_responseMap(response)).requireData();
  }
}
