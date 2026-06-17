import '../../approvals/approval_audit.dart';
import '../../approvals/approval_models.dart';
import '../../approvals/approval_request_type.dart';
import '../../approvals/approval_requests.dart';
import '../repository_query.dart';

/// Contract for unified cross-module approval persistence (mock or API).
abstract class ApprovalRepository {
  Future<List<ApprovalRequest>> listPending({
    required RepositoryQuery query,
  });

  Future<List<ApprovalRequest>> listByFilter({
    required RepositoryQuery query,
    required ApprovalListFilter filter,
  });

  Future<ApprovalRequest?> getById({
    required RepositoryQuery query,
    required String approvalId,
  });

  /// Returns an existing pending request for the same entity + type, if any.
  Future<ApprovalRequest?> findPendingByEntity({
    required RepositoryQuery query,
    required ApprovalRequestType type,
    required String entityType,
    required String entityId,
  });

  Future<ApprovalRequest> submit({
    required RepositoryQuery query,
    required SubmitApprovalRequest request,
  });

  Future<ApprovalRequest> approve({
    required RepositoryQuery query,
    required ApproveApprovalRequest request,
  });

  Future<ApprovalRequest> reject({
    required RepositoryQuery query,
    required RejectApprovalRequest request,
  });

  Future<ApprovalRequest> cancel({
    required RepositoryQuery query,
    required CancelApprovalRequest request,
  });

  Future<List<ApprovalAuditEntry>> listAuditEntries({
    required RepositoryQuery query,
    String? approvalRequestId,
  });

  Future<ApprovalAuditEntry> recordAuditEntry({
    required RepositoryQuery query,
    required ApprovalAuditEntry entry,
  });
}
