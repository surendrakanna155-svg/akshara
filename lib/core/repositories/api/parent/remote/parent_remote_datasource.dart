import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../../../../../features/parent/parent_requests.dart';
import '../../../../reliability/model/mutation_outcome.dart';
import '../../../../reliability/policy/operation_policy_registry.dart';
import '../../../../reliability/reliable_datasource_write.dart';
import '../../../../reliability/reliable_writer.dart';
import '../../teacher/dto/teacher_responses_dto.dart';
import '../dto/parent_communication_dto.dart';
import '../dto/parent_message_send_request_dto.dart';
import '../dto/parent_leave_submit_request_dto.dart';
import '../dto/parent_payment_request_dto.dart';
import '../dto/parent_responses_dto.dart';
import 'parent_api_paths.dart';

/// Dio-backed remote data source for Parent mobile APIs.
///
/// The leave-application write routes through the Data Reliability Platform's
/// [ReliableWriter] when one is injected (queued offline, replayed exactly-once,
/// optimistic while pending); otherwise it falls back to a direct Dio call.
class ParentRemoteDataSource {
  ParentRemoteDataSource(this._dio, {ReliableWriter? reliableWriter})
      : _reliable = reliableWriter;

  final Dio _dio;
  final ReliableWriter? _reliable;

  Future<ParentDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return ParentDashboardDto.fromJson(_responseMap(response));
  }

  Future<ParentAttendanceResponseDto> fetchAttendance({
    required RepositoryQuery query,
    required DateTime month,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.attendance,
      queryParameters: {
        ..._queryParams(query),
        'month': _monthParam(month),
      },
    );
    return ParentAttendanceResponseDto.fromJson(_responseMap(response));
  }

  Future<ParentHomeworkResponseDto> fetchHomework({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.homework,
      queryParameters: _queryParams(query),
    );
    return ParentHomeworkResponseDto.fromJson(_responseMap(response));
  }

  Future<ParentExamsResponseDto> fetchExams({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.exams,
      queryParameters: _queryParams(query),
    );
    return ParentExamsResponseDto.fromJson(_responseMap(response));
  }

  Future<ParentTimetableResponseDto> fetchTimetable({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.timetable,
      queryParameters: _queryParams(query),
    );
    return ParentTimetableResponseDto.fromJson(_responseMap(response));
  }

  Future<ParentFeesResponseDto> fetchFees({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.fees,
      queryParameters: _queryParams(query),
    );
    return ParentFeesResponseDto.fromJson(_responseMap(response));
  }

  Future<ParentReceiptsResponseDto> fetchReceipts({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.receipts,
      queryParameters: _queryParams(query),
    );
    return ParentReceiptsResponseDto.fromJson(_responseMap(response));
  }

  Future<ParentNoticesResponseDto> fetchNotices({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.notices,
      queryParameters: _queryParams(query),
    );
    return ParentNoticesResponseDto.fromJson(_responseMap(response));
  }

  Future<ParentEventsResponseDto> fetchEvents({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.events,
      queryParameters: _queryParams(query),
    );
    return ParentEventsResponseDto.fromJson(_responseMap(response));
  }

  Future<ParentLeaveResponseDto> fetchLeaveHistory({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.leave,
      queryParameters: _queryParams(query),
    );
    return ParentLeaveResponseDto.fromJson(_responseMap(response));
  }

  Future<ParentProfileResponseDto> fetchProfile({
    required RepositoryQuery query,
    required String activeChildId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.profile,
      queryParameters: {
        ..._queryParams(query),
        'activeChildId': activeChildId,
      },
    );
    return ParentProfileResponseDto.fromJson(_responseMap(response));
  }

  Future<ParentPaymentSummaryResponseDto> fetchPaymentSummary({
    required RepositoryQuery query,
    required String installmentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.paymentSummary(installmentId),
      queryParameters: _queryParams(query),
    );
    return ParentPaymentSummaryResponseDto.fromJson(_responseMap(response));
  }

  Future<ParentLeaveRequestDto> submitLeaveRequest({
    required RepositoryQuery query,
    required ParentLeaveSubmitRequest request,
  }) async {
    final Map<String, dynamic> data = await _reliableWrite(
      type: OperationTypes.applyLeave,
      method: 'POST',
      path: ParentApiPaths.leave,
      query: query,
      body: ParentLeaveSubmitRequestDto.fromDomain(request).toJson(),
      entityRef: 'leave:${request.childId}',
      optimistic: () => <String, dynamic>{
        'id': 'pending-${request.childId}-${request.fromDateLabel}',
        'childClass': '',
        'fromDateLabel': request.fromDateLabel,
        'toDateLabel': request.toDateLabel,
        'reason': request.reason,
        'type': ParentLeaveSubmitRequestDto.fromDomain(request).toJson()['type'],
        'status': 'pending',
        'submittedLabel': 'Pending sync',
        'timeline': const <dynamic>[],
        'hasAttachment': request.hasAttachment,
        if (request.attachmentName != null)
          'attachmentName': request.attachmentName,
      },
    );
    return ParentLeaveRequestDto.fromJson(data);
  }

  /// Routes a pilot-critical write through the reliability platform when a
  /// [ReliableWriter] is available; otherwise a direct Dio call (legacy/online).
  /// Returns the response `data` map — the server row when confirmed, or
  /// [optimistic]'s projection when the write was queued offline.
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

  Future<ParentPaymentInitiationResponseDto> initiatePayment({
    required RepositoryQuery query,
    required ParentPaymentInitiateRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ParentApiPaths.paymentsInitiate,
      queryParameters: _queryParams(query),
      data: ParentPaymentInitiateRequestDto.fromDomain(request).toJson(),
    );
    return ParentPaymentInitiationResponseDto.fromJson(_requireData(response));
  }

  Future<ParentPaymentConfirmationResponseDto> confirmPayment({
    required RepositoryQuery query,
    required ParentPaymentConfirmRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ParentApiPaths.paymentsConfirm,
      queryParameters: _queryParams(query),
      data: ParentPaymentConfirmRequestDto.fromDomain(request).toJson(),
    );
    return ParentPaymentConfirmationResponseDto.fromJson(_requireData(response));
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
      // Module-scoped params (e.g. activeChildId for multi-child parents — PAR-1).
      ...query.additionalQueryParams,
    };
  }

  String _monthParam(DateTime month) {
    final m = month.month.toString().padLeft(2, '0');
    return '${month.year}-$m';
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(_responseMap(response)).requireData();
  }

  Future<Map<String, dynamic>> fetchAcademicSummary({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.academicSummary,
      queryParameters: {..._queryParams(query), 'studentId': studentId},
    );
    return _requireData(response);
  }

  Future<String> fetchPrintableReport({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.printableReport,
      queryParameters: {..._queryParams(query), 'studentId': studentId},
    );
    return _requireData(response)['report'] as String? ?? '';
  }

  Future<TeacherMessagesResponseDto> fetchMessageThreads({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.messages,
      queryParameters: _queryParams(query),
    );
    return TeacherMessagesResponseDto.fromJson(_responseMap(response));
  }

  Future<MessageThreadDto> sendMessage({
    required RepositoryQuery query,
    required ParentMessageSendRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ParentApiPaths.messages,
      queryParameters: _queryParams(query),
      data: ParentMessageSendRequestDto.fromDomain(request).toJson(),
    );
    return MessageThreadDto.fromJson(_requireData(response));
  }

  Future<ParentCommunicationInboxResponseDto> fetchCommunicationInbox({
    required RepositoryQuery query,
    required String activeChildId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.communicationInbox,
      queryParameters: {
        ..._queryParams(query),
        'activeChildId': activeChildId,
      },
    );
    return ParentCommunicationInboxResponseDto.fromJson(_responseMap(response));
  }

  Future<ParentCommunicationMessageResponseDto> fetchCommunicationMessage({
    required RepositoryQuery query,
    required String communicationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ParentApiPaths.communicationMessage(communicationId),
      queryParameters: _queryParams(query),
    );
    return ParentCommunicationMessageResponseDto.fromJson(
      _responseMap(response),
    );
  }

  Future<void> markCommunicationRead({
    required RepositoryQuery query,
    required String communicationId,
  }) async {
    await _dio.post<void>(
      ParentApiPaths.communicationRead(communicationId),
      queryParameters: _queryParams(query),
    );
  }

  Future<void> acknowledgeCommunication({
    required RepositoryQuery query,
    required String communicationId,
  }) async {
    await _dio.post<void>(
      ParentApiPaths.communicationAcknowledge(communicationId),
      queryParameters: _queryParams(query),
    );
  }
}
