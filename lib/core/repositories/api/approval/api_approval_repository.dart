import '../../../approvals/approval_audit.dart';
import '../../../approvals/approval_models.dart';
import '../../../approvals/approval_request_type.dart';
import '../../../approvals/approval_requests.dart';
import '../api_exception.dart';
import '../../interfaces/approval_repository.dart';
import '../../repository_query.dart';

/// API stub — throws until backend approval endpoints are available.
class ApiApprovalRepository implements ApprovalRepository {
  Never _notConnected(String method) {
    throw ApiNotConnectedException('ApprovalRepository', method);
  }

  @override
  Future<ApprovalRequest> approve({
    required RepositoryQuery query,
    required ApproveApprovalRequest request,
  }) =>
      _notConnected('approve');

  @override
  Future<ApprovalRequest> cancel({
    required RepositoryQuery query,
    required CancelApprovalRequest request,
  }) =>
      _notConnected('cancel');

  @override
  Future<ApprovalRequest?> findPendingByEntity({
    required RepositoryQuery query,
    required ApprovalRequestType type,
    required String entityType,
    required String entityId,
  }) =>
      _notConnected('findPendingByEntity');

  @override
  Future<ApprovalRequest?> getById({
    required RepositoryQuery query,
    required String approvalId,
  }) =>
      _notConnected('getById');

  @override
  Future<List<ApprovalAuditEntry>> listAuditEntries({
    required RepositoryQuery query,
    String? approvalRequestId,
  }) =>
      _notConnected('listAuditEntries');

  @override
  Future<List<ApprovalRequest>> listByFilter({
    required RepositoryQuery query,
    required ApprovalListFilter filter,
  }) =>
      _notConnected('listByFilter');

  @override
  Future<List<ApprovalRequest>> listPending({
    required RepositoryQuery query,
  }) =>
      _notConnected('listPending');

  @override
  Future<ApprovalAuditEntry> recordAuditEntry({
    required RepositoryQuery query,
    required ApprovalAuditEntry entry,
  }) =>
      _notConnected('recordAuditEntry');

  @override
  Future<ApprovalRequest> reject({
    required RepositoryQuery query,
    required RejectApprovalRequest request,
  }) =>
      _notConnected('reject');

  @override
  Future<ApprovalRequest> submit({
    required RepositoryQuery query,
    required SubmitApprovalRequest request,
  }) =>
      _notConnected('submit');
}
