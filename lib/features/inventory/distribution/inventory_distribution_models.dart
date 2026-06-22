class InvCatalogItem {
  const InvCatalogItem({
    required this.id,
    required this.category,
    required this.name,
    this.skuCode,
    required this.unitPrice,
    required this.stockOnHand,
  });

  final String id;
  final String category;
  final String name;
  final String? skuCode;
  final int unitPrice;
  final int stockOnHand;
}

class InvStudentDistribution {
  const InvStudentDistribution({
    required this.id,
    required this.studentId,
    required this.catalogItemId,
    this.itemName,
    this.category,
    required this.quantity,
    required this.status,
    this.distributedAt,
    this.acknowledgedAt,
    this.paymentRequestId,
  });

  final String id;
  final String studentId;
  final String catalogItemId;
  final String? itemName;
  final String? category;
  final int quantity;
  final String status;
  final String? distributedAt;
  final String? acknowledgedAt;
  final String? paymentRequestId;
}

class InvDistributionDashboard {
  const InvDistributionDashboard({
    required this.pendingDistributions,
    required this.replacementRequests,
    required this.paymentPending,
    required this.distributedToday,
    required this.byCategory,
  });

  final int pendingDistributions;
  final int replacementRequests;
  final int paymentPending;
  final int distributedToday;
  final List<Map<String, dynamic>> byCategory;
}

/// RMA lifecycle row for FV-12 replacement workflow.
class InvReplacementRequest {
  const InvReplacementRequest({
    required this.id,
    required this.distributionId,
    required this.studentId,
    this.itemName,
    this.category,
    required this.quantity,
    required this.status,
    this.notes,
    required this.requestedAt,
    this.resolvedAt,
    this.rejectionReason,
  });

  final String id;
  final String distributionId;
  final String studentId;
  final String? itemName;
  final String? category;
  final int quantity;
  /// pending · approved · fulfilled · rejected
  final String status;
  final String? notes;
  final String requestedAt;
  final String? resolvedAt;
  final String? rejectionReason;
}
