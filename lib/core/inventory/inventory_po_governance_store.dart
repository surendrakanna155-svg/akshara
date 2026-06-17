/// Tracks inventory PO approval side effects in mock mode (M-D6).
class InventoryPoGovernanceStore {
  InventoryPoGovernanceStore._();

  static final InventoryPoGovernanceStore instance = InventoryPoGovernanceStore._();

  final Set<String> approvedOrderIds = {};
  final Map<String, String> rejectionNotesByOrderId = {};
  final Map<String, String> creatorByOrderId = {};

  void registerOrder({required String orderId, required String requestedBy}) {
    creatorByOrderId[orderId] = requestedBy;
  }

  void approveOrder(String orderId) => approvedOrderIds.add(orderId);

  void recordRejection(String orderId, String comment) {
    if (comment.isNotEmpty) rejectionNotesByOrderId[orderId] = comment;
  }

  bool isApproved(String orderId) => approvedOrderIds.contains(orderId);

  void reset() {
    approvedOrderIds.clear();
    rejectionNotesByOrderId.clear();
    creatorByOrderId.clear();
  }
}
