import '../../approvals/approval_audit.dart';
import '../../approvals/approval_exceptions.dart';
import '../../approvals/approval_models.dart';
import '../../approvals/approval_request_type.dart';
import '../../approvals/approval_requests.dart';
import '../../approvals/approval_status.dart';
import '../interfaces/approval_repository.dart';
import '../repository_query.dart';

/// In-memory approval store for development, tests, and pilot mock mode.
class MockApprovalRepository implements ApprovalRepository {
  MockApprovalRepository();

  final List<ApprovalRequest> _requests = [];
  final List<ApprovalAuditEntry> _auditEntries = [];
  int _idCounter = 0;
  int _auditCounter = 0;

  /// Clears all in-memory data — for tests only.
  void reset() {
    _requests.clear();
    _auditEntries.clear();
    _idCounter = 0;
    _auditCounter = 0;
  }

  @override
  Future<List<ApprovalRequest>> listPending({
    required RepositoryQuery query,
  }) {
    return Future.value(
      _scoped(query)
          .where((r) => r.status == ApprovalStatus.pending)
          .toList(growable: false),
    );
  }

  @override
  Future<List<ApprovalRequest>> listByFilter({
    required RepositoryQuery query,
    required ApprovalListFilter filter,
  }) {
    return Future.value(
      _scoped(query).where((r) => _matchesFilter(r, filter)).toList(growable: false),
    );
  }

  @override
  Future<ApprovalRequest?> getById({
    required RepositoryQuery query,
    required String approvalId,
  }) async {
    return _findScoped(query, approvalId);
  }

  @override
  Future<ApprovalRequest?> findPendingByEntity({
    required RepositoryQuery query,
    required ApprovalRequestType type,
    required String entityType,
    required String entityId,
  }) async {
    final matches = _scoped(query).where(
      (r) =>
          r.status == ApprovalStatus.pending &&
          r.type == type &&
          r.entityType == entityType &&
          r.entityId == entityId,
    );
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<ApprovalRequest> submit({
    required RepositoryQuery query,
    required SubmitApprovalRequest request,
  }) async {
    final created = ApprovalRequest(
      id: _nextId(),
      type: request.type,
      status: ApprovalStatus.pending,
      title: request.title,
      summary: request.summary,
      requesterId: request.requesterId,
      requesterName: request.requesterName,
      entityType: request.entityType,
      entityId: request.entityId,
      payload: Map<String, Object?>.from(request.payload),
      createdAt: DateTime.now().toUtc(),
      tenantId: query.tenantId,
      schoolId: query.schoolId,
    );
    _requests.add(created);
    return created;
  }

  @override
  Future<ApprovalRequest> approve({
    required RepositoryQuery query,
    required ApproveApprovalRequest request,
  }) async {
    return _decide(
      query: query,
      approvalId: request.approvalId,
      status: ApprovalStatus.approved,
      actorId: request.actorId,
      actorName: request.actorName,
      comment: request.comment,
    );
  }

  @override
  Future<ApprovalRequest> reject({
    required RepositoryQuery query,
    required RejectApprovalRequest request,
  }) async {
    if (request.comment.trim().isEmpty) {
      throw ApprovalRejectCommentRequiredException(request.approvalId);
    }
    return _decide(
      query: query,
      approvalId: request.approvalId,
      status: ApprovalStatus.rejected,
      actorId: request.actorId,
      actorName: request.actorName,
      comment: request.comment.trim(),
    );
  }

  @override
  Future<ApprovalRequest> cancel({
    required RepositoryQuery query,
    required CancelApprovalRequest request,
  }) async {
    return _decide(
      query: query,
      approvalId: request.approvalId,
      status: ApprovalStatus.cancelled,
      actorId: request.actorId,
      actorName: request.actorName,
      comment: request.comment,
    );
  }

  @override
  Future<BatchDecisionResult> batchDecide({
    required RepositoryQuery query,
    required BatchDecideApprovalsRequest request,
  }) async {
    // Mirror the backend contract: reject requires a non-empty comment; fail the
    // WHOLE batch up front (matches the single-reject 422), not per-item skips.
    final isReject = request.decision == ApprovalBatchDecision.reject;
    if (isReject && (request.comment?.trim().isEmpty ?? true)) {
      throw ApprovalRejectCommentRequiredException(
        request.ids.isEmpty ? 'batch' : request.ids.first,
      );
    }

    final status =
        isReject ? ApprovalStatus.rejected : ApprovalStatus.approved;
    final comment = request.comment?.trim();
    final decided = <ApprovalBatchDecidedItem>[];
    final skipped = <ApprovalBatchSkippedItem>[];
    // De-dupe ids so a repeated id can't be decided twice in one batch.
    final seen = <String>{};

    for (final id in request.ids) {
      if (!seen.add(id)) {
        skipped.add(ApprovalBatchSkippedItem(id: id, reason: 'duplicate'));
        continue;
      }
      final index = _indexScoped(query, id);
      if (index == null) {
        skipped.add(ApprovalBatchSkippedItem(id: id, reason: 'not found'));
        continue;
      }
      final current = _requests[index];
      if (current.status != ApprovalStatus.pending) {
        skipped.add(ApprovalBatchSkippedItem(id: id, reason: 'not pending'));
        continue;
      }
      _requests[index] = current.copyWith(
        status: status,
        decidedAt: DateTime.now().toUtc(),
        decidedById: request.actorId,
        decidedByName: request.actorName,
        decisionComment: comment,
      );
      decided.add(ApprovalBatchDecidedItem(id: id, status: status));
    }

    return BatchDecisionResult(decided: decided, skipped: skipped);
  }

  @override
  Future<List<ApprovalAuditEntry>> listAuditEntries({
    required RepositoryQuery query,
    String? approvalRequestId,
  }) async {
    final scoped = _auditEntries.where((e) => e.tenantId == query.tenantId);
    if (approvalRequestId == null) {
      return scoped.toList(growable: false);
    }
    return scoped
        .where((e) => e.approvalRequestId == approvalRequestId)
        .toList(growable: false);
  }

  @override
  Future<ApprovalAuditEntry> recordAuditEntry({
    required RepositoryQuery query,
    required ApprovalAuditEntry entry,
  }) async {
    final stored = ApprovalAuditEntry(
      id: entry.id.isEmpty ? _nextAuditId() : entry.id,
      approvalRequestId: entry.approvalRequestId,
      action: entry.action,
      actorId: entry.actorId,
      actorName: entry.actorName,
      occurredAt: entry.occurredAt,
      comment: entry.comment,
      tenantId: entry.tenantId ?? query.tenantId,
      schoolId: entry.schoolId ?? query.schoolId,
      metadata: entry.metadata,
    );
    _auditEntries.add(stored);
    return stored;
  }

  Future<ApprovalRequest> _decide({
    required RepositoryQuery query,
    required String approvalId,
    required ApprovalStatus status,
    required String actorId,
    required String actorName,
    String? comment,
  }) async {
    final index = _indexScoped(query, approvalId);
    if (index == null) {
      throw ApprovalNotFoundException(approvalId);
    }
    final current = _requests[index];
    if (current.status != ApprovalStatus.pending) {
      throw ApprovalInvalidStateException(
        approvalId: approvalId,
        currentStatus: current.status.name,
        action: status.name,
      );
    }
    final updated = current.copyWith(
      status: status,
      decidedAt: DateTime.now().toUtc(),
      decidedById: actorId,
      decidedByName: actorName,
      decisionComment: comment,
    );
    _requests[index] = updated;
    return updated;
  }

  Iterable<ApprovalRequest> _scoped(RepositoryQuery query) {
    return _requests.where(
      (r) =>
          r.tenantId == query.tenantId &&
          (query.schoolId == null || r.schoolId == query.schoolId),
    );
  }

  ApprovalRequest? _findScoped(RepositoryQuery query, String approvalId) {
    final index = _indexScoped(query, approvalId);
    return index == null ? null : _requests[index];
  }

  int? _indexScoped(RepositoryQuery query, String approvalId) {
    for (var i = 0; i < _requests.length; i++) {
      final item = _requests[i];
      if (item.id == approvalId &&
          item.tenantId == query.tenantId &&
          (query.schoolId == null || item.schoolId == query.schoolId)) {
        return i;
      }
    }
    return null;
  }

  bool _matchesFilter(ApprovalRequest request, ApprovalListFilter filter) {
    if (filter.status != null && request.status != filter.status) {
      return false;
    }
    if (filter.type != null && request.type != filter.type) {
      return false;
    }
    if (filter.requesterId != null &&
        request.requesterId != filter.requesterId) {
      return false;
    }
    if (filter.entityType != null &&
        request.entityType != filter.entityType) {
      return false;
    }
    if (filter.entityId != null && request.entityId != filter.entityId) {
      return false;
    }
    return true;
  }

  String _nextId() {
    _idCounter += 1;
    return 'appr_${_idCounter.toString().padLeft(6, '0')}';
  }

  String _nextAuditId() {
    _auditCounter += 1;
    return 'appr_audit_${_auditCounter.toString().padLeft(6, '0')}';
  }
}
