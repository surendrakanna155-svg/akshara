import '../../../../features/parent/academics/parent_academic_models.dart';
import '../../../../features/parent/attendance/attendance_models.dart';
import '../../../../features/parent/dashboard/parent_dashboard_provider.dart';
import '../../../../features/parent/events/events_models.dart';
import '../../../../features/parent/exams/exam_models.dart';
import '../../../../features/parent/fees/fee_certificate_models.dart';
import '../../../../features/parent/fees/fees_provider.dart';
import '../../../../features/parent/homework/homework_models.dart';
import '../../../../features/parent/leave/leave_models.dart';
import '../../../../features/parent/notices/notices_models.dart';
import '../../../../features/parent/parent_requests.dart';
import '../../../../features/parent/payment/payment_models.dart';
import '../../../../features/parent/profile/profile_models.dart';
import '../../../../features/parent/receipts/receipt_models.dart';
import '../../../../features/parent/timetable/timetable_models.dart';
import '../../../../features/teacher/messages/message_models.dart';
import '../../../communication/parent_communication_models.dart';
import '../../interfaces/parent_repository.dart';
import '../../repository_query.dart';
import 'mapper/parent_mapper.dart';
import 'remote/parent_remote_datasource.dart';

/// API implementation of [ParentRepository] — enabled via [parentApiEnabledProvider].
class ApiParentRepository implements ParentRepository {
  ApiParentRepository({
    required ParentRemoteDataSource remote,
    ParentMapper mapper = const ParentMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final ParentRemoteDataSource _remote;
  final ParentMapper _mapper;

  @override
  Future<ParentDashboardData> getDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.fetchDashboard(query: query);
    return _mapper.toDashboard(dto);
  }

  @override
  Future<AttendanceMonthData> getAttendance({
    required RepositoryQuery query,
    required DateTime month,
  }) async {
    final dto = await _remote.fetchAttendance(query: query, month: month);
    return _mapper.toAttendance(dto);
  }

  @override
  Future<ParentHomeworkData> getHomework({required RepositoryQuery query}) async {
    final dto = await _remote.fetchHomework(query: query);
    return _mapper.toHomework(dto);
  }

  @override
  Future<ParentExamsData> getExams({required RepositoryQuery query}) async {
    final dto = await _remote.fetchExams(query: query);
    return _mapper.toExams(dto);
  }

  @override
  Future<ParentTimetableData> getTimetable({required RepositoryQuery query}) async {
    final dto = await _remote.fetchTimetable(query: query);
    return _mapper.toTimetable(dto);
  }

  @override
  Future<ParentFeesData> getFees({required RepositoryQuery query}) async {
    final dto = await _remote.fetchFees(query: query);
    return _mapper.toFees(dto);
  }

  @override
  Future<List<FeeReceipt>> getReceipts({required RepositoryQuery query}) async {
    final dto = await _remote.fetchReceipts(query: query);
    return _mapper.toReceipts(dto);
  }

  @override
  Future<FeeCertificateData> getFeeCertificate({
    required RepositoryQuery query,
    String? academicYear,
  }) async {
    final dto = await _remote.fetchFeeCertificate(
      query: query,
      academicYear: academicYear,
    );
    return _mapper.toFeeCertificate(dto);
  }

  @override
  Future<List<ParentNotice>> getNotices({required RepositoryQuery query}) async {
    final dto = await _remote.fetchNotices(query: query);
    return _mapper.toNotices(dto);
  }

  @override
  Future<ParentEventsData> getEvents({required RepositoryQuery query}) async {
    final dto = await _remote.fetchEvents(query: query);
    return _mapper.toEvents(dto);
  }

  @override
  Future<List<LeaveRequest>> getLeaveHistory({required RepositoryQuery query}) async {
    final dto = await _remote.fetchLeaveHistory(query: query);
    return _mapper.toLeaveHistory(dto);
  }

  @override
  Future<ParentProfileData> getProfile({
    required RepositoryQuery query,
    required String activeChildId,
  }) async {
    final dto = await _remote.fetchProfile(
      query: query,
      activeChildId: activeChildId,
    );
    return _mapper.toProfile(dto);
  }

  @override
  Future<PaymentSummary> getPaymentSummary({
    required RepositoryQuery query,
    required String installmentId,
  }) async {
    final dto = await _remote.fetchPaymentSummary(
      query: query,
      installmentId: installmentId,
    );
    return _mapper.toPaymentSummary(dto);
  }

  @override
  Future<LeaveRequest> submitLeaveRequest({
    required RepositoryQuery query,
    required ParentLeaveSubmitRequest request,
  }) async {
    final dto = await _remote.submitLeaveRequest(query: query, request: request);
    return _mapper.toLeaveRequest(dto);
  }

  @override
  Future<ParentLeaveCancelResult> cancelLeaveRequest({
    required RepositoryQuery query,
    required String leaveId,
  }) async {
    final raw = await _remote.cancelLeaveRequest(query: query, leaveId: leaveId);
    return _mapper.toLeaveCancelResult(raw);
  }

  @override
  Future<ParentLeaveAttachmentResult> attachLeaveDocument({
    required RepositoryQuery query,
    required String leaveId,
    required String fileName,
    String? storagePath,
  }) async {
    final raw = await _remote.attachLeaveDocument(
      query: query,
      leaveId: leaveId,
      fileName: fileName,
      storagePath: storagePath,
    );
    return _mapper.toLeaveAttachmentResult(raw);
  }

  @override
  Future<PaymentInitiationResult> initiatePayment({
    required RepositoryQuery query,
    required ParentPaymentInitiateRequest request,
  }) async {
    final dto = await _remote.initiatePayment(query: query, request: request);
    return _mapper.toPaymentInitiation(dto);
  }

  @override
  Future<PaymentConfirmationResult> confirmPayment({
    required RepositoryQuery query,
    required ParentPaymentConfirmRequest request,
  }) async {
    final dto = await _remote.confirmPayment(query: query, request: request);
    return _mapper.toPaymentConfirmation(dto);
  }

  @override
  Future<ParentAcademicSummary> getAcademicSummary({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final dto = await _remote.fetchAcademicSummary(query: query, studentId: studentId);
    return ParentAcademicSummary(
      studentId: dto['studentId'] as String? ?? studentId,
      attendanceSummary: Map<String, dynamic>.from(dto['attendanceSummary'] as Map? ?? {}),
      performanceSummary: Map<String, dynamic>.from(dto['performanceSummary'] as Map? ?? {}),
      strengths: (dto['strengths'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      weaknesses: (dto['weaknesses'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      homeworkStatus: Map<String, dynamic>.from(dto['homeworkStatus'] as Map? ?? {}),
      examReadiness: Map<String, dynamic>.from(dto['examReadiness'] as Map? ?? {}),
      teacherRecommendations:
          (dto['teacherRecommendations'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      generatedAt: dto['generatedAt'] as String? ?? '',
    );
  }

  @override
  Future<String> getPrintableReport({
    required RepositoryQuery query,
    required String studentId,
  }) =>
      _remote.fetchPrintableReport(query: query, studentId: studentId);

  @override
  Future<List<MessageThread>> getMessageThreads({required RepositoryQuery query}) async {
    final dto = await _remote.fetchMessageThreads(query: query);
    return [
      for (final thread in dto.items)
        if (thread.raw.isNotEmpty)
        MessageThread(
          id: thread.raw['id'] as String? ?? '',
          parentName: thread.raw['parentName'] as String? ?? '',
          studentName: thread.raw['studentName'] as String? ?? '',
          preview: thread.raw['preview'] as String? ?? '',
          timeLabel: thread.raw['timeLabel'] as String? ?? '',
          unreadCount: (thread.raw['unreadCount'] as num?)?.toInt() ?? 0,
          messages: [
            for (final item in (thread.raw['messages'] as List<dynamic>? ?? const []))
              if (item is Map<String, dynamic>)
              MessageItem(
                id: item['id'] as String? ?? '',
                body: item['body'] as String? ?? '',
                senderLabel: item['senderLabel'] as String? ?? '',
                timeLabel: item['timeLabel'] as String? ?? '',
                isTeacher: item['isTeacher'] as bool? ?? false,
              ),
          ],
        ),
    ];
  }

  @override
  Future<MessageThread> sendMessage({
    required RepositoryQuery query,
    required ParentMessageSendRequest request,
  }) async {
    final thread = await _remote.sendMessage(query: query, request: request);
    return MessageThread(
      id: thread.raw['id'] as String? ?? '',
      parentName: thread.raw['parentName'] as String? ?? '',
      studentName: thread.raw['studentName'] as String? ?? '',
      preview: thread.raw['preview'] as String? ?? '',
      timeLabel: thread.raw['timeLabel'] as String? ?? '',
      unreadCount: (thread.raw['unreadCount'] as num?)?.toInt() ?? 0,
      messages: [
        for (final item in (thread.raw['messages'] as List<dynamic>? ?? const []))
          if (item is Map<String, dynamic>)
          MessageItem(
            id: item['id'] as String? ?? '',
            body: item['body'] as String? ?? '',
            senderLabel: item['senderLabel'] as String? ?? '',
            timeLabel: item['timeLabel'] as String? ?? '',
            isTeacher: item['isTeacher'] as bool? ?? false,
          ),
      ],
    );
  }

  @override
  Future<List<ParentCommunicationInboxItem>> getCommunicationInbox({
    required RepositoryQuery query,
    required String activeChildId,
  }) async {
    // PRA-N-10 (S0/T2-E): fail closed — return the live inbox (an empty inbox is
    // a valid state), never the in-memory mock fallback. The old code diverted to
    // ParentCommunicationInboxFallback on any error OR a successful-but-empty
    // response, showing fabricated notices resolved against a demo student.
    final dto = await _remote.fetchCommunicationInbox(
      query: query,
      activeChildId: activeChildId,
    );
    return _mapper.toCommunicationInbox(dto);
  }

  @override
  Future<ParentCommunicationInboxItem?> getCommunicationMessage({
    required RepositoryQuery query,
    required String communicationId,
  }) async {
    // PRA-N-10 (S0/T2-E): fail closed — surface the real message or the error.
    final dto = await _remote.fetchCommunicationMessage(
      query: query,
      communicationId: communicationId,
    );
    return _mapper.toCommunicationInboxItem(dto.raw);
  }

  @override
  Future<void> markCommunicationRead({
    required RepositoryQuery query,
    required String communicationId,
  }) async {
    // PRA-N-10 (S0/T2-E): fail closed — a failed read-receipt must surface, not
    // be faked in a device-local store the server never sees.
    await _remote.markCommunicationRead(
      query: query,
      communicationId: communicationId,
    );
  }

  @override
  Future<void> acknowledgeCommunication({
    required RepositoryQuery query,
    required String communicationId,
  }) async {
    // PRA-N-10 (S0/T2-E): fail closed — a parent's acknowledgement of a school
    // notice must reach the server or error, never a silent local fake.
    await _remote.acknowledgeCommunication(
      query: query,
      communicationId: communicationId,
    );
  }
}
