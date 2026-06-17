import '../../finance/finance_approval_governance_store.dart';
import '../../repositories/repository_query.dart';
import '../approval_models.dart';
import '../approval_request_type.dart';
import '../approval_center_service.dart';
import '../approval_requests.dart';
import 'approval_type_adapter.dart';

class FeeStructureApprovalAdapter implements ApprovalTypeAdapter {
  FeeStructureApprovalAdapter({FinanceApprovalGovernanceStore? store})
      : _store = store ?? FinanceApprovalGovernanceStore.instance;

  final FinanceApprovalGovernanceStore _store;
  static const entityType = 'fee_structure';

  Future<ApprovalRequest> submitForApproval({
    required ApprovalCenterService service,
    required RepositoryQuery query,
    required String feeStructureId,
    required String requesterId,
    required String requesterName,
    required Map<String, Object?> payload,
    required String title,
    required String summary,
  }) {
    return service.submitApprovalRequest(
      query: query,
      request: SubmitApprovalRequest(
        type: ApprovalRequestType.feeStructure,
        title: title,
        summary: summary,
        requesterId: requesterId,
        requesterName: requesterName,
        entityType: entityType,
        entityId: feeStructureId,
        payload: payload,
      ),
    );
  }

  @override
  void onApproved({
    required RepositoryQuery query,
    required ApprovalRequest request,
  }) {
    if (request.type != ApprovalRequestType.feeStructure) return;
    _store.activateFeeStructure(request.entityId);
  }

  @override
  void onRejected({
    required RepositoryQuery query,
    required ApprovalRequest request,
    required String comment,
  }) {
    if (request.type != ApprovalRequestType.feeStructure) return;
    _store.recordRejection(request.entityId, comment);
  }

  @override
  Map<String, String> enrichDetail(ApprovalRequest request) {
    if (request.type != ApprovalRequestType.feeStructure) return const {};
    final p = request.payload;
    return {
      'Structure': '${p['name'] ?? request.title}',
      'Academic year': '${p['academicYear'] ?? '—'}',
      'Class range': '${p['classRange'] ?? '—'}',
      'Annual total': '${p['totalAnnual'] ?? '—'}',
    };
  }
}

class FeeConcessionApprovalAdapter implements ApprovalTypeAdapter {
  FeeConcessionApprovalAdapter({FinanceApprovalGovernanceStore? store})
      : _store = store ?? FinanceApprovalGovernanceStore.instance;

  final FinanceApprovalGovernanceStore _store;
  static const entityType = 'fee_concession';

  Future<ApprovalRequest> submitForApproval({
    required ApprovalCenterService service,
    required RepositoryQuery query,
    required String concessionId,
    required String requesterId,
    required String requesterName,
    required Map<String, Object?> payload,
    required String title,
    required String summary,
  }) {
    return service.submitApprovalRequest(
      query: query,
      request: SubmitApprovalRequest(
        type: ApprovalRequestType.feeConcession,
        title: title,
        summary: summary,
        requesterId: requesterId,
        requesterName: requesterName,
        entityType: entityType,
        entityId: concessionId,
        payload: payload,
      ),
    );
  }

  @override
  void onApproved({
    required RepositoryQuery query,
    required ApprovalRequest request,
  }) {
    if (request.type != ApprovalRequestType.feeConcession) return;
    _store.applyConcession(request.entityId);
  }

  @override
  void onRejected({
    required RepositoryQuery query,
    required ApprovalRequest request,
    required String comment,
  }) {
    if (request.type != ApprovalRequestType.feeConcession) return;
    _store.recordRejection(request.entityId, comment);
  }

  @override
  Map<String, String> enrichDetail(ApprovalRequest request) {
    if (request.type != ApprovalRequestType.feeConcession) return const {};
    final p = request.payload;
    return {
      'Student': '${p['studentName'] ?? '—'}',
      'Amount': '${p['amount'] ?? '—'}',
      'Reason': '${p['reason'] ?? request.summary}',
    };
  }
}

class RefundApprovalAdapter implements ApprovalTypeAdapter {
  RefundApprovalAdapter({FinanceApprovalGovernanceStore? store})
      : _store = store ?? FinanceApprovalGovernanceStore.instance;

  final FinanceApprovalGovernanceStore _store;
  static const entityType = 'refund_request';

  Future<ApprovalRequest> submitForApproval({
    required ApprovalCenterService service,
    required RepositoryQuery query,
    required String refundId,
    required String requesterId,
    required String requesterName,
    required Map<String, Object?> payload,
    required String title,
    required String summary,
  }) {
    return service.submitApprovalRequest(
      query: query,
      request: SubmitApprovalRequest(
        type: ApprovalRequestType.refund,
        title: title,
        summary: summary,
        requesterId: requesterId,
        requesterName: requesterName,
        entityType: entityType,
        entityId: refundId,
        payload: payload,
      ),
    );
  }

  @override
  void onApproved({
    required RepositoryQuery query,
    required ApprovalRequest request,
  }) {
    if (request.type != ApprovalRequestType.refund) return;
    _store.approveRefund(request.entityId);
  }

  @override
  void onRejected({
    required RepositoryQuery query,
    required ApprovalRequest request,
    required String comment,
  }) {
    if (request.type != ApprovalRequestType.refund) return;
    _store.recordRejection(request.entityId, comment);
  }

  @override
  Map<String, String> enrichDetail(ApprovalRequest request) {
    if (request.type != ApprovalRequestType.refund) return const {};
    final p = request.payload;
    return {
      'Student': '${p['studentName'] ?? '—'}',
      'Amount': '${p['amount'] ?? '—'}',
      'Reason': '${p['reason'] ?? request.summary}',
    };
  }
}
