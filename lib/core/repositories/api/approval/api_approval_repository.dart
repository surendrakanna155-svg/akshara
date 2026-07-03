import 'package:dio/dio.dart';

import '../../../approvals/approval_audit.dart';
import '../../../approvals/approval_exceptions.dart';
import '../../../approvals/approval_models.dart';
import '../../../approvals/approval_request_type.dart';
import '../../../approvals/approval_requests.dart';
import '../../../approvals/approval_status.dart';
import '../../interfaces/approval_repository.dart';
import '../../repository_query.dart';
import '../admissions/dto/api_envelope_dto.dart';
import 'dto/approval_request_payload_dto.dart';
import 'mapper/approval_mapper.dart';
import 'remote/approval_remote_datasource.dart';

/// API implementation of [ApprovalRepository] — enabled via [approvalApiEnabledProvider].
class ApiApprovalRepository implements ApprovalRepository {
  ApiApprovalRepository({
    required ApprovalRemoteDataSource remote,
    ApprovalMapper mapper = const ApprovalMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final ApprovalRemoteDataSource _remote;
  final ApprovalMapper _mapper;

  @override
  Future<List<ApprovalRequest>> listPending({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchPending(query: query);
    return rows.map(_mapper.toDomain).toList(growable: false);
  }

  @override
  Future<List<ApprovalRequest>> listByFilter({
    required RepositoryQuery query,
    required ApprovalListFilter filter,
  }) async {
    final rows = await _remote.fetchByFilter(
      query: query,
      filter: ApprovalListFilterQuery(
        status: filter.status?.name,
        type: filter.type,
        requesterId: filter.requesterId,
        entityType: filter.entityType,
        entityId: filter.entityId,
      ),
    );
    return rows.map(_mapper.toDomain).toList(growable: false);
  }

  @override
  Future<ApprovalRequest?> getById({
    required RepositoryQuery query,
    required String approvalId,
  }) async {
    final row = await _remote.fetchById(query: query, approvalId: approvalId);
    return row == null ? null : _mapper.toDomain(row);
  }

  @override
  Future<ApprovalRequest?> findPendingByEntity({
    required RepositoryQuery query,
    required ApprovalRequestType type,
    required String entityType,
    required String entityId,
  }) async {
    final row = await _remote.fetchPendingByEntity(
      query: query,
      filter: ApprovalListFilterQuery(
        type: type,
        entityType: entityType,
        entityId: entityId,
      ),
    );
    return row == null ? null : _mapper.toDomain(row);
  }

  @override
  Future<ApprovalRequest> submit({
    required RepositoryQuery query,
    required SubmitApprovalRequest request,
  }) async {
    try {
      final row = await _remote.submit(
        query: query,
        request: SubmitApprovalRequestDto.fromDomain(request),
      );
      return _mapper.toDomain(row);
    } on DioException catch (error) {
      throw _mapDioError(error, request.type.name);
    }
  }

  @override
  Future<ApprovalRequest> approve({
    required RepositoryQuery query,
    required ApproveApprovalRequest request,
  }) async {
    try {
      final row = await _remote.approve(
        query: query,
        approvalId: request.approvalId,
        request: DecideApprovalRequestDto(
          actorId: request.actorId,
          actorName: request.actorName,
          comment: request.comment,
        ),
      );
      return _mapper.toDomain(row);
    } on DioException catch (error) {
      throw _mapDioError(error, request.approvalId);
    }
  }

  @override
  Future<ApprovalRequest> reject({
    required RepositoryQuery query,
    required RejectApprovalRequest request,
  }) async {
    if (request.comment.trim().isEmpty) {
      throw ApprovalRejectCommentRequiredException(request.approvalId);
    }
    try {
      final row = await _remote.reject(
        query: query,
        approvalId: request.approvalId,
        request: DecideApprovalRequestDto(
          actorId: request.actorId,
          actorName: request.actorName,
          comment: request.comment.trim(),
        ),
      );
      return _mapper.toDomain(row);
    } on DioException catch (error) {
      throw _mapDioError(error, request.approvalId);
    }
  }

  @override
  Future<ApprovalRequest> cancel({
    required RepositoryQuery query,
    required CancelApprovalRequest request,
  }) async {
    try {
      final row = await _remote.cancel(
        query: query,
        approvalId: request.approvalId,
        request: DecideApprovalRequestDto(
          actorId: request.actorId,
          actorName: request.actorName,
          comment: request.comment,
        ),
      );
      return _mapper.toDomain(row);
    } on DioException catch (error) {
      throw _mapDioError(error, request.approvalId);
    }
  }

  @override
  Future<BatchDecisionResult> batchDecide({
    required RepositoryQuery query,
    required BatchDecideApprovalsRequest request,
  }) async {
    final isReject = request.decision == ApprovalBatchDecision.reject;
    // Mirror the single-reject + backend contract: a batch reject requires a
    // non-empty comment. Fail before the round-trip (server 422s on the same).
    if (isReject && (request.comment?.trim().isEmpty ?? true)) {
      throw ApprovalRejectCommentRequiredException(
        request.ids.isEmpty ? 'batch' : request.ids.first,
      );
    }
    try {
      final dto = await _remote.batchDecide(
        query: query,
        request: BatchDecideApprovalsRequestDto(
          ids: request.ids,
          decision: isReject ? 'reject' : 'approve',
          comment: request.comment?.trim(),
        ),
      );
      return _mapper.batchToDomain(dto);
    } on DioException catch (error) {
      throw _mapDioError(error, 'batch');
    }
  }

  @override
  Future<List<ApprovalAuditEntry>> listAuditEntries({
    required RepositoryQuery query,
    String? approvalRequestId,
  }) async {
    final rows = await _remote.fetchAuditEntries(
      query: query,
      approvalRequestId: approvalRequestId,
    );
    return rows.map(_mapper.auditToDomain).toList(growable: false);
  }

  @override
  Future<ApprovalAuditEntry> recordAuditEntry({
    required RepositoryQuery query,
    required ApprovalAuditEntry entry,
  }) async {
    // Server is source of truth for audit in API mode — no-op mirror.
    return entry;
  }

  Never _mapDioError(DioException error, String approvalId) {
    final envelope = _envelopeFrom(error);
    final code = envelope?.error?.code ?? '';
    final message = envelope?.error?.message ?? error.message ?? 'Approval API error';

    if (error.response?.statusCode == 404 || code == 'NOT_FOUND') {
      throw ApprovalNotFoundException(approvalId);
    }
    if (code == 'VALIDATION_ERROR') {
      if (message.toLowerCase().contains('comment')) {
        throw ApprovalRejectCommentRequiredException(approvalId);
      }
      final statusMatch = RegExp(r'status=(\w+)').firstMatch(message);
      throw ApprovalInvalidStateException(
        approvalId: approvalId,
        currentStatus: statusMatch?.group(1) ?? 'unknown',
        action: 'decide',
      );
    }
    if (error.response?.statusCode == 403 || code == 'FORBIDDEN') {
      throw ApprovalInvalidStateException(
        approvalId: approvalId,
        currentStatus: ApprovalStatus.pending.name,
        action: 'forbidden',
      );
    }
    Error.throwWithStackTrace(error, error.stackTrace);
  }

  ApiEnvelopeDto? _envelopeFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      return ApiEnvelopeDto.fromJson(data);
    }
    return null;
  }
}
