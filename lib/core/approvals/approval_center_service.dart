import '../approvals/approval_audit.dart';
import '../approvals/approval_exceptions.dart';
import '../approvals/approval_models.dart';
import '../approvals/approval_request_type.dart';
import '../approvals/approval_requests.dart';
import '../repositories/api/approval/api_approval_repository.dart';
import '../repositories/interfaces/approval_repository.dart';
import '../repositories/repository_query.dart';

/// Single write path for cross-module approval requests (Phase D infrastructure).
class ApprovalCenterService {
  ApprovalCenterService(this._repository);

  final ApprovalRepository _repository;

  bool get _serverManagesAudit => _repository is ApiApprovalRepository;

  Future<List<ApprovalRequest>> listPending({
    required RepositoryQuery query,
  }) {
    return _repository.listPending(query: query);
  }

  Future<List<ApprovalRequest>> listByFilter({
    required RepositoryQuery query,
    required ApprovalListFilter filter,
  }) {
    return _repository.listByFilter(query: query, filter: filter);
  }

  Future<ApprovalRequest?> getById({
    required RepositoryQuery query,
    required String approvalId,
  }) {
    return _repository.getById(query: query, approvalId: approvalId);
  }

  Future<List<ApprovalAuditEntry>> listAuditEntries({
    required RepositoryQuery query,
    String? approvalRequestId,
  }) {
    return _repository.listAuditEntries(
      query: query,
      approvalRequestId: approvalRequestId,
    );
  }

  Future<ApprovalRequest?> findPendingByEntity({
    required RepositoryQuery query,
    required ApprovalRequestType type,
    required String entityType,
    required String entityId,
  }) {
    return _repository.findPendingByEntity(
      query: query,
      type: type,
      entityType: entityType,
      entityId: entityId,
    );
  }

  /// Submits a new approval request, or returns an existing pending duplicate.
  Future<ApprovalRequest> submitApprovalRequest({
    required RepositoryQuery query,
    required SubmitApprovalRequest request,
  }) async {
    final existing = await _repository.findPendingByEntity(
      query: query,
      type: request.type,
      entityType: request.entityType,
      entityId: request.entityId,
    );
    if (existing != null) {
      return existing;
    }

    final created = await _repository.submit(query: query, request: request);
    if (!_serverManagesAudit) {
      await _recordAudit(
        query: query,
        approvalRequestId: created.id,
        action: ApprovalAuditAction.submitted,
        actorId: request.requesterId,
        actorName: request.requesterName,
        comment: null,
      );
    }
    return created;
  }

  Future<ApprovalRequest> approveRequest({
    required RepositoryQuery query,
    required ApproveApprovalRequest request,
  }) async {
    final updated = await _repository.approve(query: query, request: request);
    if (!_serverManagesAudit) {
      await _recordAudit(
        query: query,
        approvalRequestId: updated.id,
        action: ApprovalAuditAction.approved,
        actorId: request.actorId,
        actorName: request.actorName,
        comment: request.comment,
      );
    }
    return updated;
  }

  Future<ApprovalRequest> rejectRequest({
    required RepositoryQuery query,
    required RejectApprovalRequest request,
  }) async {
    if (request.comment.trim().isEmpty) {
      throw ApprovalRejectCommentRequiredException(request.approvalId);
    }
    final updated = await _repository.reject(query: query, request: request);
    if (!_serverManagesAudit) {
      await _recordAudit(
        query: query,
        approvalRequestId: updated.id,
        action: ApprovalAuditAction.rejected,
        actorId: request.actorId,
        actorName: request.actorName,
        comment: request.comment.trim(),
      );
    }
    return updated;
  }

  /// PRI-1 — batch approve/reject. The server (API mode) owns the audit trail
  /// and per-item authority; in mock mode there is no per-item RBAC, so the
  /// caller (notifier) enforces the reachability permission. Audit rows are
  /// recorded per decided id in mock mode to mirror the single-decision path.
  Future<BatchDecisionResult> batchDecide({
    required RepositoryQuery query,
    required BatchDecideApprovalsRequest request,
  }) async {
    final result = await _repository.batchDecide(query: query, request: request);
    if (!_serverManagesAudit) {
      final action = request.decision == ApprovalBatchDecision.approve
          ? ApprovalAuditAction.approved
          : ApprovalAuditAction.rejected;
      for (final item in result.decided) {
        await _recordAudit(
          query: query,
          approvalRequestId: item.id,
          action: action,
          actorId: request.actorId,
          actorName: request.actorName,
          comment: request.comment?.trim(),
        );
      }
    }
    return result;
  }

  Future<ApprovalRequest> cancelRequest({
    required RepositoryQuery query,
    required CancelApprovalRequest request,
  }) async {
    final updated = await _repository.cancel(query: query, request: request);
    if (!_serverManagesAudit) {
      await _recordAudit(
        query: query,
        approvalRequestId: updated.id,
        action: ApprovalAuditAction.cancelled,
        actorId: request.actorId,
        actorName: request.actorName,
        comment: request.comment,
      );
    }
    return updated;
  }

  Future<void> _recordAudit({
    required RepositoryQuery query,
    required String approvalRequestId,
    required ApprovalAuditAction action,
    required String actorId,
    required String actorName,
    String? comment,
  }) {
    return _repository.recordAuditEntry(
      query: query,
      entry: ApprovalAuditEntry(
        id: '',
        approvalRequestId: approvalRequestId,
        action: action,
        actorId: actorId,
        actorName: actorName,
        occurredAt: DateTime.now().toUtc(),
        comment: comment,
        tenantId: query.tenantId,
        schoolId: query.schoolId,
      ),
    );
  }
}
