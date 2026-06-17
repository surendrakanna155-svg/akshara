/// Tracks finance approval side effects in mock mode (M-D5).
class FinanceApprovalGovernanceStore {
  FinanceApprovalGovernanceStore._();

  static final FinanceApprovalGovernanceStore instance =
      FinanceApprovalGovernanceStore._();

  final Set<String> activatedFeeStructureIds = {};
  final Set<String> appliedConcessionIds = {};
  final Set<String> approvedRefundIds = {};
  final Map<String, String> rejectionNotesByEntityId = {};

  void activateFeeStructure(String id) => activatedFeeStructureIds.add(id);
  void applyConcession(String id) => appliedConcessionIds.add(id);
  void approveRefund(String id) => approvedRefundIds.add(id);

  void recordRejection(String entityId, String comment) {
    if (comment.isEmpty) return;
    rejectionNotesByEntityId[entityId] = comment;
  }

  void reset() {
    activatedFeeStructureIds.clear();
    appliedConcessionIds.clear();
    approvedRefundIds.clear();
    rejectionNotesByEntityId.clear();
  }
}
