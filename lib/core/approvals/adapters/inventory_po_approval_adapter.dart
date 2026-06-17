import '../../errors/api_failure.dart';
import '../../inventory/inventory_po_governance_store.dart';
import '../../repositories/repository_query.dart';
import '../approval_center_service.dart';
import '../approval_models.dart';
import '../approval_request_type.dart';
import '../approval_requests.dart';
import 'approval_type_adapter.dart';

/// Inventory PO maker-checker adapter (M-D6).
class InventoryPoApprovalAdapter implements ApprovalTypeAdapter {
  InventoryPoApprovalAdapter({InventoryPoGovernanceStore? store})
      : _store = store ?? InventoryPoGovernanceStore.instance;

  final InventoryPoGovernanceStore _store;

  static const entityType = 'procurement_order';

  Future<ApprovalRequest> submitForApproval({
    required ApprovalCenterService service,
    required RepositoryQuery query,
    required String orderId,
    required String requesterId,
    required String requesterName,
    required Map<String, Object?> payload,
    required String title,
    required String summary,
  }) {
    _store.registerOrder(
      orderId: orderId,
      requestedBy: requesterId,
    );
    return service.submitApprovalRequest(
      query: query,
      request: SubmitApprovalRequest(
        type: ApprovalRequestType.inventoryPo,
        title: title,
        summary: summary,
        requesterId: requesterId,
        requesterName: requesterName,
        entityType: entityType,
        entityId: orderId,
        payload: payload,
      ),
    );
  }

  @override
  void onApproved({
    required RepositoryQuery query,
    required ApprovalRequest request,
  }) {
    if (request.type != ApprovalRequestType.inventoryPo) return;
    _store.approveOrder(request.entityId);
  }

  @override
  void onRejected({
    required RepositoryQuery query,
    required ApprovalRequest request,
    required String comment,
  }) {
    if (request.type != ApprovalRequestType.inventoryPo) return;
    _store.recordRejection(request.entityId, comment);
  }

  @override
  Map<String, String> enrichDetail(ApprovalRequest request) {
    if (request.type != ApprovalRequestType.inventoryPo) return const {};
    final p = request.payload;
    return {
      'PO': '${p['poNumber'] ?? request.entityId}',
      'Vendor': '${p['vendorName'] ?? '—'}',
      'Amount': '${p['totalAmount'] ?? '—'}',
      'Requested by': '${p['requestedBy'] ?? request.requesterName}',
    };
  }

  /// Blocks creator from approving own PO (segregation of duties).
  static void assertApproverNotCreator({
    required ApprovalRequest request,
    required String actorId,
  }) {
    final creator = InventoryPoGovernanceStore.instance
        .creatorByOrderId[request.entityId];
    if (creator != null && creator == actorId) {
      throw ApiFailureException(
        const ApiFailure(
          type: ApiFailureType.forbidden,
          message: 'You cannot approve a purchase order you created.',
          code: 'PO_SELF_APPROVE_DENIED',
        ),
      );
    }
  }
}
